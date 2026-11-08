class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  # One household per account: a household id from the URL is only accepted when
  # it is the current user's own, anything else is a 404.
  def find_own_household!(id)
    household = current_user.household
    raise ActiveRecord::RecordNotFound unless household && household.id == id.to_i

    household
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :time_zone ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :time_zone ])
  end
end
