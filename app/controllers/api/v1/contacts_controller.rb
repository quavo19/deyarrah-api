module Api
  module V1
    class ContactsController < BaseController
      before_action :authenticate_admin!, only: [ :index, :destroy ]
      before_action :set_contact_message, only: [ :destroy ]

      # Public: create contact message
      def create
        authorize ContactMessage

        payload = params.require(:contact).permit(:purpose, :message, :name, :email, :phone)
        contact_message = ContactMessage.new(payload)

        if contact_message.save
          render json: { data: serialize_contact_message(contact_message) }, status: :created
        else
          render json: {
            error: "Validation failed",
            errors: contact_message.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # Admin: list all contact messages (optionally filtered)
      def index
        authorize ContactMessage

        contact_messages = policy_scope(ContactMessage).order(created_at: :desc)

        # Optional filtering (case-insensitive contains)
        if params[:query].present?
          q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].to_s.strip)}%"
          contact_messages = contact_messages.where(
            "email ILIKE ? OR name ILIKE ? OR phone ILIKE ?",
            q, q, q
          )
        end

        if params[:email].present?
          email = "%#{ActiveRecord::Base.sanitize_sql_like(params[:email].to_s.strip)}%"
          contact_messages = contact_messages.where("email ILIKE ?", email)
        end

        if params[:name].present?
          name = "%#{ActiveRecord::Base.sanitize_sql_like(params[:name].to_s.strip)}%"
          contact_messages = contact_messages.where("name ILIKE ?", name)
        end

        if params[:phone].present?
          phone = "%#{ActiveRecord::Base.sanitize_sql_like(params[:phone].to_s.strip)}%"
          contact_messages = contact_messages.where("phone ILIKE ?", phone)
        end

        render json: {
          data: contact_messages.map { |cm| serialize_contact_message(cm) }
        }, status: :ok
      end

      # Admin: delete contact message
      def destroy
        authorize @contact_message

        if @contact_message.destroy
          render json: { data: serialize_contact_message(@contact_message) }, status: :ok
        else
          render json: {
            error: "Failed to delete contact message",
            errors: @contact_message.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_contact_message
        @contact_message = policy_scope(ContactMessage).find_by(id: params[:id])
        unless @contact_message
          render json: { error: "Contact message not found" }, status: :not_found
          nil
        end
      end

      def serialize_contact_message(contact_message)
        {
          id: contact_message.id,
          type: "contact_message",
          attributes: {
            purpose: contact_message.purpose,
            message: contact_message.message,
            name: contact_message.name,
            email: contact_message.email,
            phone: contact_message.phone,
            created_at: contact_message.created_at.iso8601,
            updated_at: contact_message.updated_at.iso8601
          }
        }
      end
    end
  end
end

