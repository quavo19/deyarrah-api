module Api
  module V1
    class DeliverySettingsController < BaseController
      before_action :authenticate_admin!

      def show
        render json: { data: setting_json(setting) }, status: :ok
      end

      def update
        multiplier = params.dig(:delivery_setting, :high_value_additional_unit_multiplier)
        multiplier ||= params.dig(:delivery_setting, :multiplier)

        if multiplier.blank? || multiplier.to_d.negative?
          render json: { error: "Validation failed", errors: [ "Multiplier must be 0 or greater" ] }, status: :unprocessable_entity
          return
        end

        setting.update!(value: { multiplier: multiplier.to_f })
        render json: { data: setting_json(setting) }, status: :ok
      end

      private

      def setting
        @setting ||= DeliverySetting.find_or_create_by!(key: "high_value_additional_unit_multiplier") do |record|
          record.value = { multiplier: 0.75 }
        end
      end

      def setting_json(record)
        {
          id: record.id,
          type: "delivery_setting",
          attributes: {
            high_value_additional_unit_multiplier: record.value["multiplier"].to_f
          }
        }
      end
    end
  end
end
