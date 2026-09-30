module Api
  module V1
    class AffiliateClicksController < BaseController
      CLICK_DEDUP_WINDOW = 30.days
      CLICK_RATE_LIMIT = 60
      CLICK_RATE_LIMIT_WINDOW = 1.minute

      def create
        unless click_rate_allowed?
          render json: { error: "Too many affiliate clicks. Please try again shortly." }, status: :too_many_requests
          return
        end

        product = Product.find_by(id: click_params[:product_id], active: true)
        unless product
          render json: { error: "Product not found" }, status: :not_found
          return
        end

        profile = AffiliateProfile.includes(:user).find_by(
          affiliate_code: click_params[:affiliate_code].to_s.strip.upcase,
          status: "approved"
        )
        unless profile&.user&.active_affiliate?
          render json: { error: "Affiliate link is not active" }, status: :unprocessable_entity
          return
        end

        visitor_id = click_params[:visitor_id].presence
        buyer_user = current_user
        ip_hash = hashed_ip

        if buyer_user&.id == profile.user_id
          render json: { error: "Affiliates cannot track their own clicks" }, status: :unprocessable_entity
          return
        end

        unless buyer_user || visitor_id
          render json: { error: "Visitor id is required" }, status: :unprocessable_entity
          return
        end

        click = duplicate_click(profile.user, product, buyer_user, visitor_id, ip_hash)
        recorded = false

        unless click
          click = AffiliateClick.create!(
            affiliate_user: profile.user,
            buyer_user: buyer_user,
            product: product,
            visitor_id: visitor_id,
            ip_hash: ip_hash,
            referrer: click_params[:referrer_url],
            user_agent: request.user_agent
          )
          recorded = true
        end

        attribution = existing_attribution(product, buyer_user, visitor_id)
        attributed = false

        unless attribution
          attribution = AffiliateAttribution.create!(
            affiliate_user: profile.user,
            buyer_user: buyer_user,
            product: product,
            affiliate_click: click,
            visitor_id: visitor_id
          )
          attributed = true
        else
          claim_visitor_attribution!(attribution, buyer_user) if buyer_user
        end

        render json: {
          data: {
            id: click.id,
            type: "affiliate_click",
            attributes: {
              recorded: recorded,
              attributed: attributed,
              attribution_id: attribution.id,
              affiliate_code: profile.affiliate_code,
              product_id: product.id,
              clicked_at: click.clicked_at.iso8601
            }
          }
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def click_params
        params.require(:affiliate_click).permit(
          :affiliate_code,
          :product_id,
          :visitor_id,
          :landing_url,
          :referrer_url
        )
      end

      def existing_attribution(product, buyer_user, visitor_id)
        scope = AffiliateAttribution.where(product: product)
        buyer_attribution = scope.find_by(buyer_user: buyer_user) if buyer_user
        return buyer_attribution if buyer_attribution

        scope.find_by(buyer_user_id: nil, visitor_id: visitor_id) if visitor_id.present?
      end

      def duplicate_click(affiliate_user, product, buyer_user, visitor_id, ip_hash)
        scope = AffiliateClick
          .where(affiliate_user: affiliate_user, product: product)
          .where("clicked_at > ?", CLICK_DEDUP_WINDOW.ago)

        buyer_match = scope.where(buyer_user: buyer_user).first if buyer_user
        return buyer_match if buyer_match

        visitor_match = scope.where(visitor_id: visitor_id).first if visitor_id.present?
        return visitor_match if visitor_match

        scope.where(ip_hash: ip_hash).first if ip_hash.present?
      end

      def claim_visitor_attribution!(attribution, buyer_user)
        return if attribution.buyer_user_id.present?

        attribution.update!(buyer_user: buyer_user)
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def hashed_ip
        ip = request.remote_ip.to_s
        return nil if ip.blank?

        secret = Rails.application.secret_key_base
        Digest::SHA256.hexdigest("#{secret}:#{ip}")
      end

      def click_rate_allowed?
        key_parts = [
          "affiliate_click_rate",
          hashed_ip.presence || "no-ip",
          click_params[:visitor_id].presence || "no-visitor"
        ]
        cache_key = key_parts.join(":")
        count = Rails.cache.read(cache_key).to_i
        return false if count >= CLICK_RATE_LIMIT

        Rails.cache.write(cache_key, count + 1, expires_in: CLICK_RATE_LIMIT_WINDOW)
        true
      rescue NotImplementedError, NoMethodError
        true
      end
    end
  end
end
