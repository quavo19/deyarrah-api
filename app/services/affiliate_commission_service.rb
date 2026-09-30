class AffiliateCommissionService
  class << self
    def claim_visitor_attributions!(order, visitor_id)
      visitor_id = visitor_id.to_s.strip
      return if order.blank? || visitor_id.blank?

      product_ids = products_for(order).map(&:id)
      return if product_ids.empty?

      product_ids.each do |product_id|
        next if AffiliateAttribution.exists?(product_id: product_id, buyer_user_id: order.user_id)

        attribution = AffiliateAttribution
          .where(product_id: product_id, visitor_id: visitor_id, buyer_user_id: nil)
          .where("expires_at > ?", Time.current)
          .order(:attributed_at)
          .first
        next unless attribution

        attribution.update!(buyer_user: order.user)
      rescue ActiveRecord::RecordNotUnique
        next
      end
    end

    def create_for_order!(order)
      return unless order&.received?

      order.with_lock do
        order.order_items.includes(variant_stock: :product).find_each do |order_item|
          create_for_order_item!(order, order_item)
        end

        create_signup_referral_earning!(order)
      end
    end

    def cancel_for_order!(order)
      return unless order

      order.with_lock do
        order.affiliate_earnings
          .where(status: %w[pending available])
          .update_all(status: "cancelled", updated_at: Time.current)
      end
    end

    private

    def create_for_order_item!(order, order_item)
      return if AffiliateEarning.exists?(order_item_id: order_item.id)

      product = order_item.variant_stock&.product
      return unless product

      commission_per_unit = product.affiliate_commission_amount.to_d
      return unless commission_per_unit.positive?

      attribution = AffiliateAttribution
        .where(product: product, buyer_user: order.user)
        .where("expires_at > ?", Time.current)
        .order(:attributed_at)
        .first
      return unless attribution
      return if attribution.affiliate_user_id == order.user_id

      AffiliateEarning.create!(
        affiliate_user: attribution.affiliate_user,
        buyer_user: order.user,
        order: order,
        order_item: order_item,
        product: product,
        affiliate_attribution: attribution,
        sale_amount: order_item.price,
        commission_amount: commission_per_unit * order_item.quantity.to_i,
        currency: "GHS",
        status: "pending",
        earning_type: "product_commission",
        earned_at: Time.current
      )

      attribution.update!(converted_at: Time.current) if attribution.converted_at.blank?
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def create_signup_referral_earning!(order)
      referral = AffiliateSignupReferral.find_by(referred_user: order.user)
      return unless referral
      return if referral.affiliate_user_id == order.user_id
      return if referral.rewarded_orders_count.to_i >= 3
      return if AffiliateEarning.exists?(affiliate_signup_referral: referral, order: order)

      settings = AffiliateSetting.current
      return unless settings.signup_referral_enabled?

      percentage = settings.signup_referral_percentage.to_d
      cap = settings.signup_referral_cap_amount.to_d
      return unless percentage.positive? && cap.positive?

      sale_amount = order.total_price.to_d
      uncapped_commission = sale_amount * percentage / 100
      commission_amount = [ uncapped_commission, cap ].min
      return unless commission_amount.positive?

      AffiliateEarning.create!(
        affiliate_user: referral.affiliate_user,
        buyer_user: order.user,
        order: order,
        affiliate_signup_referral: referral,
        sale_amount: sale_amount,
        commission_amount: commission_amount,
        currency: "GHS",
        status: "pending",
        earning_type: "signup_referral",
        earned_at: Time.current
      )

      referral.update!(
        rewarded_orders_count: referral.rewarded_orders_count.to_i + 1,
        converted_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def products_for(order)
      order.order_items.includes(variant_stock: :product).filter_map do |order_item|
        order_item.variant_stock&.product
      end.uniq
    end
  end
end
