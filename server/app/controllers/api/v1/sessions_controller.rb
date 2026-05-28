module Api
  module V1
    # Lets a client confirm its token and learn who it belongs to.
    class SessionsController < BaseController
      def show
        render json: { id: current_user.id, email: current_user.email, name: current_user.name }
      end
    end
  end
end
