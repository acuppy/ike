module Api
  module V1
    # Token-authenticated JSON base. Clients (the macOS widget, future iOS app)
    # send `Authorization: Bearer <api_token>`.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_token!

      # Scoping every lookup through current_user.blocks means another user's
      # id simply isn't found; surface that as a clean 404 rather than a 500.
      rescue_from ActiveRecord::RecordNotFound do
        head :not_found
      end

      attr_reader :current_user

      private

      def authenticate_token!
        authenticate_or_request_with_http_token do |token, _options|
          # Only confirmed accounts may use the API — same gate as web sign-in.
          @current_user = User.confirmed.find_by(api_token: token)
        end
      end
    end
  end
end
