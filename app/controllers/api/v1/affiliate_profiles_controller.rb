module Api
  module V1
    class AffiliateProfilesController < BaseController
      before_action :authenticate_user!
      before_action :set_profile, only: [ :show, :update ]

      def show
        if @profile
          render json: {
            data: serialize(@profile, detail: true),
            application_status: @profile.status
          }, status: :ok
        else
          render json: {
            data: nil,
            application_status: "not_applied"
          }, status: :ok
        end
      end

      def create
        existing_profile = current_user.affiliate_profile

        if existing_profile && !existing_profile.can_reapply?
          render json: {
            error: existing_profile.reapplication_block_reason || "Affiliate application cannot be resubmitted yet",
            data: serialize(existing_profile, detail: true)
          }, status: existing_profile.active_application? ? :conflict : :forbidden
          return
        end

        profile = existing_profile || current_user.build_affiliate_profile
        profile.assign_attributes(affiliate_profile_params)
        profile.status = "pending"
        profile.reviewed_by = nil
        profile.reviewed_at = nil
        profile.rejection_reason = nil
        profile.suspended_at = nil

        if profile.save
          render json: {
            data: serialize(profile, detail: true),
            message: "Affiliate application submitted successfully"
          }, status: existing_profile ? :ok : :created
        else
          render json: {
            error: "Validation failed",
            errors: profile.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update
        unless @profile
          render json: { error: "Affiliate application not found" }, status: :not_found
          return
        end

        unless %w[pending rejected].include?(@profile.status)
          render json: { error: "Approved or suspended affiliate applications cannot be edited by the applicant" }, status: :forbidden
          return
        end

        if @profile.status == "rejected" && !@profile.can_reapply?
          render json: {
            error: @profile.reapplication_block_reason,
            data: serialize(@profile, detail: true)
          }, status: :forbidden
          return
        end

        @profile.assign_attributes(affiliate_profile_params)
        @profile.status = "pending" if @profile.status == "rejected"
        @profile.reviewed_by = nil
        @profile.reviewed_at = nil
        @profile.rejection_reason = nil
        @profile.suspended_at = nil

        if @profile.save
          render json: {
            data: serialize(@profile, detail: true),
            message: "Affiliate application updated successfully"
          }, status: :ok
        else
          render json: {
            error: "Validation failed",
            errors: @profile.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_profile
        @profile = current_user.affiliate_profile
      end

      def affiliate_profile_params
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

      def serialize(profile, detail: false)
        AffiliateProfileSerializer.new(profile, detail: detail).as_json
      end
    end
  end
end
