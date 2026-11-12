module BackOffice
  # Enrolment of the second factor. The secret is shown only to a session that
  # (1) arrived through the one-time link given out of band (`redeem`, see
  # BackOffice::Console) and (2) signed in with the password. A password alone,
  # leaked or guessed, shows nothing. Not an ActiveAdmin page: the gate would
  # send an un-enrolled admin back here.
  class TwoFactorsController < ApplicationController
    include BackOfficeGate

    SESSION_TOKEN = :admin_enrolment_token

    layout "active_admin_logged_out"
    helper ::ActiveAdmin::LayoutHelper
    helper ::ActiveAdmin::FormHelper

    before_action :authenticate_admin_user!, except: :redeem
    before_action :redirect_if_enrolled, except: :redeem
    before_action :require_enrolment_link, only: %i[show create]

    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to back_office_two_factor_path, alert: t("back_office.two_factor.rate_limited") }

    # GET /admin/two_factor/link/:token. Remembers the link in the session, then
    # on to the sign-in (and back here). Nothing is revealed by this request.
    def redeem
      session[SESSION_TOKEN] = params[:token].to_s
      redirect_to back_office_two_factor_path
    end

    def show
      assign_secret
    end

    def create
      if current_admin_user.enrol!(params[:code].to_s)
        AdminAction.record!(admin: current_admin_user, action: "two_factor.enrolled", record: current_admin_user)
        session.delete(SESSION_TOKEN)
        mark_two_factor_verified!
        redirect_to admin_root_path, notice: t("back_office.two_factor.enrolled")
      else
        register_failure
      end
    end

    private

    # Wrong codes count against the account (same threshold as passwords):
    # the per-IP rate limit alone could be spread over many addresses.
    def register_failure
      locked = current_admin_user.register_failed_enrolment!
      AdminAction.record!(admin: current_admin_user, action: "two_factor.enrolment_failed", record: current_admin_user,
                          ip: request.remote_ip)
      if locked
        AdminAction.record!(admin: current_admin_user, action: "admin.locked", record: current_admin_user,
                            via: "enrolment", ip: request.remote_ip)
        sign_out(:admin_user)
        redirect_to new_admin_user_session_path, alert: t("devise.failure.admin_user.locked")
      else
        assign_secret
        flash.now[:alert] = t("back_office.two_factor.wrong_code")
        render :show, status: :unprocessable_entity
      end
    end

    def assign_secret
      @secret = current_admin_user.otp_secret
      @provisioning_uri = current_admin_user.provisioning_uri
    end

    def redirect_if_enrolled
      redirect_to admin_root_path if current_admin_user.two_factor_enrolled?
    end

    # The link's token must still be valid (30 minutes, not used up, not
    # replaced by a newer one) and be this admin's.
    def require_enrolment_link
      token = session[SESSION_TOKEN]
      return if token.present? && AdminUser.find_by_token_for(:enrolment, token) == current_admin_user

      render :link_required, status: :forbidden
    end
  end
end
