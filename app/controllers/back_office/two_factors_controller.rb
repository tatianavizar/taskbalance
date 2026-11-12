module BackOffice
  # Enrolment of the second factor, shown at the first sign-in (and again until
  # a code has been accepted). Not an ActiveAdmin page: the gate would send
  # an un-enrolled admin back here. Everything else in /admin is refused until
  # the code is accepted.
  class TwoFactorsController < ApplicationController
    include BackOfficeGate

    layout "active_admin_logged_out"
    helper ::ActiveAdmin::LayoutHelper
    helper ::ActiveAdmin::FormHelper

    before_action :authenticate_admin_user!
    before_action :redirect_if_enrolled

    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to back_office_two_factor_path, alert: t("back_office.two_factor.rate_limited") }

    def show
      @secret = current_admin_user.ensure_otp_secret!
      @provisioning_uri = current_admin_user.provisioning_uri
    end

    def create
      if current_admin_user.enrol!(params[:code].to_s)
        AdminAction.record!(admin: current_admin_user, action: "two_factor.enrolled", record: current_admin_user)
        mark_two_factor_verified!
        redirect_to admin_root_path, notice: t("back_office.two_factor.enrolled")
      else
        @secret = current_admin_user.otp_secret
        @provisioning_uri = current_admin_user.provisioning_uri
        flash.now[:alert] = t("back_office.two_factor.wrong_code")
        render :show, status: :unprocessable_entity
      end
    end

    private

    def redirect_if_enrolled
      redirect_to admin_root_path if current_admin_user.two_factor_enrolled?
    end
  end
end
