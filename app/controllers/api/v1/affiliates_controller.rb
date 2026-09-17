module Api
  module V1
    class AffiliatesController < BaseController
      before_action :authenticate_admin!
      before_action :set_affiliate_profile, only: [ :show, :update, :approve, :reject, :suspend, :reactivate ]

      def index
        profiles = AffiliateProfile.includes(:user, :reviewed_by).order(created_at: :desc)

        profiles = profiles.where(status: params[:status]) if params[:status].present?

        if params[:search].present?
          term = "%#{params[:search]}%"
          profiles = profiles.left_joins(:user).where(
            "affiliate_profiles.full_name ILIKE :term OR affiliate_profiles.email ILIKE :term OR affiliate_profiles.phone ILIKE :term OR affiliate_profiles.affiliate_code ILIKE :term OR users.email ILIKE :term OR users.first_name ILIKE :term OR users.last_name ILIKE :term",
            term: term
          )
        end

        page = params[:page] || 1
        per_page = pagination_per_page
        profiles = profiles.page(page).per(per_page)

        render json: {
          data: profiles.map { |profile| serialize(profile, detail: true) },
          meta: {
            current_page: profiles.current_page,
            per_page: profiles.limit_value,
            total_pages: profiles.total_pages,
            total_count: profiles.total_count
          },
          statuses: status_options
        }, status: :ok
      end

      def show
        return if performed?

        render json: {
          data: serialize(@affiliate_profile, detail: true),
          statuses: status_options
        }, status: :ok
      end

      def update
        return if performed?

        if @affiliate_profile.update(admin_affiliate_profile_params)
          render json: {
            data: serialize(@affiliate_profile.reload, detail: true),
            message: "Affiliate profile updated successfully"
          }, status: :ok
        else
          render json: {
            error: "Validation failed",
            errors: @affiliate_profile.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def approve
        return if performed?

        @affiliate_profile.approve!(current_user)
        render json: {
          data: serialize(@affiliate_profile.reload, detail: true),
          message: "Affiliate approved successfully"
        }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      def reject
        return if performed?

        @affiliate_profile.reject!(current_user, review_params[:reason])
        render json: {
          data: serialize(@affiliate_profile.reload, detail: true),
          message: "Affiliate application rejected"
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      def suspend
        return if performed?

        @affiliate_profile.suspend!(current_user, review_params[:reason])
        render json: {
          data: serialize(@affiliate_profile.reload, detail: true),
          message: "Affiliate suspended successfully"
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      def reactivate
        return if performed?

        @affiliate_profile.reactivate!(current_user)
        render json: {
          data: serialize(@affiliate_profile.reload, detail: true),
          message: "Affiliate reactivated successfully"
        }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def set_affiliate_profile
        @affiliate_profile = AffiliateProfile.includes(:user, :reviewed_by).find_by(id: params[:id])
        return if @affiliate_profile

        render json: { error: "Affiliate profile not found" }, status: :not_found
      end

      def admin_affiliate_profile_params
        params.require(:affiliate_profile).permit(
          :full_name,
          :email,
          :phone,
          :country,
          :city,
          :audience_size,
          :content_niche,
          :reason,
          :terms_accepted,
          social_links: [],
          promotion_channels: [],
          payout_details: {}
        )
      end

      def review_params
        params.permit(:reason)
      end

      def serialize(profile, detail: false)
        AffiliateProfileSerializer.new(profile, detail: detail).as_json
      end

      def status_options
        AffiliateProfile::STATUS_LABELS.map { |value, label| { value: value, label: label } }
      end

      def pagination_per_page
        requested = params[:per_page].to_i
        requested = 25 if requested <= 0
        [ requested, 100 ].min
      end
    end
  end
end
