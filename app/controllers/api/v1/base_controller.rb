module Api
  module V1
    class BaseController < ApplicationController
      respond_to :json

      include Devise::Controllers::Helpers
    end
  end
end
