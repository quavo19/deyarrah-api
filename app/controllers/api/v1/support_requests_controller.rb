module Api
  module V1
    class SupportRequestsController < BaseController
      before_action :authenticate_admin!, only: [ :index, :show, :update, :destroy ]
      before_action :set_support_request, only: [ :show, :update, :destroy ]

      def index
        requests = SupportRequest.includes(:user).order(created_at: :desc)

        if params[:topic].present?
          requests = requests.where(topic: params[:topic])
        end

        if params[:status].present?
          requests = requests.where(status: params[:status])
        end

        if params[:search].present?
          term = "%#{params[:search]}%"
          requests = requests.left_joins(:user).where(
            "support_requests.message ILIKE :term OR support_requests.guest_full_name ILIKE :term OR support_requests.guest_email ILIKE :term OR users.email ILIKE :term OR users.first_name ILIKE :term OR users.last_name ILIKE :term",
            term: term
          )
        end

        page = params[:page] || 1
        per_page = pagination_per_page
        requests = requests.page(page).per(per_page)

        render json: {
          data: requests.map { |support_request| support_request_json(support_request) },
          meta: {
            current_page: requests.current_page,
            per_page: requests.limit_value,
            total_pages: requests.total_pages,
            total_count: requests.total_count
          },
          topics: topic_options,
          statuses: status_options
        }, status: :ok
      end

      def show
        return if performed?

        render json: {
          data: support_request_json(@support_request, detail: true),
          topics: topic_options,
          statuses: status_options
        }, status: :ok
      end

      def update
        return if performed?

        if @support_request.update(status_params)
          render json: {
            data: support_request_json(@support_request.reload, detail: true),
            message: "Support request updated successfully"
          }, status: :ok
        else
          render json: {
            error: "Validation failed",
            errors: @support_request.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def create
        support_request = SupportRequest.new(support_request_params)
        support_request.user = current_user if current_user

        if support_request.save
          render json: {
            data: support_request_json(support_request),
            message: "Support request submitted successfully"
          }, status: :created
        else
          render json: {
            error: "Validation failed",
            errors: support_request.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def destroy
        return if performed?

        @support_request.destroy
        render json: { message: "Support request deleted successfully" }, status: :ok
      end

      private

      def set_support_request
        @support_request = SupportRequest.includes(:user).find_by(id: params[:id])
        return if @support_request

        render json: { error: "Support request not found" }, status: :not_found
      end

      def support_request_params
        params.require(:support_request).permit(
          :topic,
          :message,
          :guest_full_name,
          :guest_email,
          :guest_phone
        )
      end

      def support_request_json(support_request, detail: false)
        user = support_request.user
        payload = {
          id: support_request.id,
          type: "support_request",
          attributes: {
            topic: support_request.topic,
            topic_label: support_request.topic_label,
            status: support_request.status,
            status_label: support_request.status_label,
            message: support_request.message,
            requester_name: support_request.requester_name,
            requester_email: support_request.requester_email,
            requester_phone: support_request.requester_phone,
            guest_full_name: support_request.guest_full_name,
            guest_email: support_request.guest_email,
            guest_phone: support_request.guest_phone,
            created_at: support_request.created_at.iso8601,
            updated_at: support_request.updated_at.iso8601,
            user: user && {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name,
              avatar: user.avatar,
              phone_numbers: user.phone_numbers || []
            }
          }
        }

        return payload if detail

        payload.deep_merge(
          attributes: {
            message_preview: support_request.message.to_s.truncate(140)
          }
        )
      end

      def topic_options
        SupportRequest::TOPICS.map { |value, label| { value: value, label: label } }
      end

      def status_options
        SupportRequest::STATUSES.map { |value, label| { value: value, label: label } }
      end

      def status_params
        params.require(:support_request).permit(:status)
      end

      def pagination_per_page
        requested = params[:per_page].to_i
        requested = 25 if requested <= 0
        [ requested, 100 ].min
      end
    end
  end
end
