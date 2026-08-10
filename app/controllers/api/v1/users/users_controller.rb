module Api
  module V1
    module Users
      class UsersController < BaseController
        before_action :authenticate_admin!
        before_action :set_user, only: [ :show, :assign_role, :assign_permissions, :unassign_permissions, :block, :unblock ]

        def index
          @users = User.all.includes(:role, :permissions)

          if params[:search].present?
            search_term = "%#{params[:search]}%"
            @users = @users.where(
              "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ? OR (first_name || ' ' || last_name) ILIKE ?",
              search_term, search_term, search_term, search_term
            )
          end

          if params[:blocked].present?
            blocked_value = ActiveModel::Type::Boolean.new.cast(params[:blocked])
            @users = @users.where(blocked: blocked_value)
          end

          if params[:role_id].present?
            @users = @users.where(role_id: params[:role_id])
          end

          if params[:role].present?
            role = Role.find_by(name: params[:role].upcase)
            if role
              @users = @users.where(role_id: role.id)
            else
              # If role name doesn't exist, return empty result
              @users = @users.none
            end
          end

          @users = @users.order(created_at: :desc)
          @users = @users.page(params[:page] || 1).per(params[:per_page] || 25)

          render json: {
            data: @users.map { |user| UserSerializer.new(user).serializable_hash[:data][:attributes] },
            meta: {
              current_page: @users.current_page,
              per_page: @users.limit_value,
              total_pages: @users.total_pages,
              total_count: @users.total_count
            }
          }, status: :ok
        end

        def show
          render json: {
            data: UserSerializer.new(@user).serializable_hash[:data][:attributes]
          }, status: :ok
        end

        def assign_role
          role_id = params[:role_id]

          unless role_id.present?
            render json: {
              error: "Role ID is required"
            }, status: :unprocessable_entity
            return
          end

          role = Role.find_by(id: role_id)
          unless role
            render json: {
              error: "Role not found"
            }, status: :not_found
            return
          end

          if @user.update(role: role)
            render json: {
              message: "Role assigned successfully",
              data: UserSerializer.new(@user.reload).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render json: {
              error: @user.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        def assign_permissions
          permission_ids = params[:permission_ids] || []

          unless permission_ids.is_a?(Array)
            render json: {
              error: "Permission IDs must be an array"
            }, status: :unprocessable_entity
            return
          end

          permissions = Permission.where(id: permission_ids)
          if permissions.count != permission_ids.count
            render json: {
              error: "One or more permission IDs are invalid"
            }, status: :unprocessable_entity
            return
          end

          @user.permissions = permissions

          render json: {
            message: "Permissions assigned successfully",
            data: UserSerializer.new(@user.reload).serializable_hash[:data][:attributes]
          }, status: :ok
        end

        def unassign_permissions
          permission_ids = params[:permission_ids] || []

          unless permission_ids.is_a?(Array)
            render json: {
              error: "Permission IDs must be an array"
            }, status: :unprocessable_entity
            return
          end

          permissions = Permission.where(id: permission_ids)
          if permissions.count != permission_ids.count
            render json: {
              error: "One or more permission IDs are invalid"
            }, status: :unprocessable_entity
            return
          end

          @user.permissions.delete(permissions)

          render json: {
            message: "Permissions unassigned successfully",
            data: UserSerializer.new(@user.reload).serializable_hash[:data][:attributes]
          }, status: :ok
        end

        def block
          if @user.update(blocked: true)
            render json: {
              message: "User blocked successfully",
              data: UserSerializer.new(@user.reload).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render json: {
              error: @user.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        def unblock
          if @user.update(blocked: false)
            render json: {
              message: "User unblocked successfully",
              data: UserSerializer.new(@user.reload).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render json: {
              error: @user.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        private

        def set_user
          @user = User.find_by(id: params[:id])
          unless @user
            render json: {
              error: "User not found"
            }, status: :not_found
          end
        end
      end
    end
  end
end
