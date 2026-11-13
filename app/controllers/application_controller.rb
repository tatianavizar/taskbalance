class ApplicationController < ActionController::Base
  include InviteeResume

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Hotwire Native shells embed a WebView that does not announce itself as a
  # browser version, so they are never blocked.
  allow_browser versions: :modern, unless: -> { hotwire_native_app? }

  default_form_builder FiftyFormBuilder

  before_action :configure_permitted_parameters, if: :devise_controller?

  # After signing in or up, land on the app's home.
  # A person in the middle of an invitation resumes it.
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || invitation_path_after_sign_in(resource) || dashboard_path
  end

  private

  # The invitation they opened before signing in, else the one they claimed.
  def invitation_path_after_sign_in(user)
    token = session.delete(:invitation_token)
    return invitation_path(token) if Invitation.live.find_by_token(token)

    invitation = pending_invitation_of(user)
    invitee_resume_path(invitation) if invitation
  end

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
