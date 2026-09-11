module Api
  module V1
    class BadgesController < BaseController
      before_action :authenticate_admin!
      before_action :set_badge, only: [ :show, :update, :destroy, :add_user, :remove_user ]

      def index
        authorize Badge

        badges = policy_scope(Badge)
                 .left_joins(:user_badges)
                 .select("badges.*, COUNT(user_badges.id) AS unlocked_count")
                 .group("badges.id")
                 .order(:name)

        render json: { data: badges.map { |badge| badge_json(badge) } }, status: :ok
      end

      def show
        authorize @badge

        render json: { data: badge_json(@badge, include_users: true) }, status: :ok
      end

      def create
        badge = Badge.new(badge_params)
        authorize badge

        if badge.save
          render json: { data: badge_json(badge) }, status: :created
        else
          render json: { error: badge.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        authorize @badge

        if @badge.update(badge_params)
          render json: { data: badge_json(@badge, include_users: true) }, status: :ok
        else
          render json: { error: @badge.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @badge
        @badge.destroy

        render json: { message: "Badge deleted successfully" }, status: :ok
      end

      def add_user
        authorize @badge, :add_user?

        user = User.find_by(id: params[:user_id])
        unless user
          render json: { error: "User not found" }, status: :not_found
          return
        end

        user_badge = UserBadge.find_or_initialize_by(user: user, badge: @badge)
        if user_badge.persisted? || user_badge.save
          render json: { data: badge_json(@badge.reload, include_users: true) }, status: :ok
        else
          render json: { error: user_badge.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def remove_user
        authorize @badge, :remove_user?

        user_badge = @badge.user_badges.find_by(user_id: params[:user_id])
        user_badge&.destroy

        render json: { data: badge_json(@badge.reload, include_users: true) }, status: :ok
      end

      private

      def set_badge
        @badge = policy_scope(Badge).includes(user_badges: :user).find_by(id: params[:id])
        return if @badge

        render json: { error: "Badge not found" }, status: :not_found
      end

      def badge_params
        params.require(:badge).permit(:name, :description, :bonus_points)
      end

      def badge_json(badge, include_users: false)
        payload = {
          id: badge.id,
          name: badge.name,
          description: badge.description,
          bonus_points: badge.bonus_points,
          unlocked_count: badge.respond_to?(:unlocked_count) ? badge.unlocked_count.to_i : badge.user_badges.size,
          created_at: badge.created_at,
          updated_at: badge.updated_at
        }

        if include_users
          payload[:users] = badge.user_badges.includes(:user).order(created_at: :desc).map do |user_badge|
            user = user_badge.user
            {
              id: user.id,
              first_name: user.first_name,
              last_name: user.last_name,
              email: user.email,
              avatar: user.avatar,
              unlocked_at: user_badge.created_at
            }
          end
        end

        payload
      end
    end
  end
end
