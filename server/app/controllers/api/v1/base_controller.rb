module Api
  module V1
    # Token-authenticated JSON base. Clients (the macOS widget, future iOS app)
    # send `Authorization: Bearer <api_token>`.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_token!

      attr_reader :current_user

      private

      def authenticate_token!
        authenticate_or_request_with_http_token do |token, _options|
          @current_user = User.find_by(api_token: token)
        end
      end
    end
  end
end
