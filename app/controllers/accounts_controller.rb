# F4: the account screen. First name, email and password each have their own
# screen. The first name needs nothing more than a session; the email and the
# password ask for the current password (a stolen session must not be enough to
# take an account over).
class AccountsController < ApplicationController
  before_action :authenticate_user!

  # A new address gets a confirmation mail (decision of 2026-11-13): 2 changes
  # per account over a rolling 24 hours (User#email_change_allowed?, counted
  # on changes that sent a mail), and 3 per hour towards the same address, so
  # nobody can flood an inbox.
  EMAIL_CHANGES_PER_ADDRESS_PER_HOUR = 3
  rate_limit to: EMAIL_CHANGES_PER_ADDRESS_PER_HOUR, within: 1.hour, only: :update_email, name: "email-change-address",
             by: -> { params.dig(:user, :email).to_s.strip.downcase.presence || "user-#{current_user.id}" },
             with: -> { email_change_rate_limited }
  before_action :check_email_change_allowance, only: %i[edit_email update_email]

  def show
  end

  def edit_first_name
  end

  def update_first_name
    if current_user.update(params.expect(user: [ :first_name ]))
      # A first name feeds the monogram: recompute it for the household.
      HouseholdMember.refresh_monograms!(current_user.household) if current_user.household
      redirect_to account_path, notice: t("auth.account.flash.first_name_updated")
    else
      render :edit_first_name, status: :unprocessable_entity
    end
  end

  # F4, Notifications: one switch per event type (D9). Types left out of the
  # form keep their setting; unknown ones are ignored.
  def update_notifications
    submitted = params.fetch(:preferences, {}).permit(*NotificationPreference::EVENT_TYPES)
    submitted.each do |event_type, value|
      NotificationPreference.set(current_user, event_type, ActiveModel::Type::Boolean.new.cast(value) == true)
    end
    redirect_to account_path, notice: t("notifications.account.saved")
  end

  # F5: the form posts to DELETE /users (Users::RegistrationsController#destroy).
  def delete_account
    @deletion = AccountDeletion.new(current_user)
  end

  def edit_email
  end

  def update_email
    return redirect_to(edit_email_path) if @email_change_blocked_until

    if current_user.update_with_password(params.expect(user: [ :email, :current_password ]))
      # A confirmation mail went out (a new token): that is what counts.
      current_user.record_email_change! if current_user.pending_reconfirmation? && current_user.saved_change_to_confirmation_token?
      notice = current_user.pending_reconfirmation? ? t("auth.account.flash.email_updated") : nil
      redirect_to(current_user.pending_reconfirmation? ? pending_user_confirmation_path : account_path, notice: notice)
    else
      current_user.clean_up_passwords
      render :edit_email, status: :unprocessable_entity
    end
  end

  def edit_password
  end

  def update_password
    attributes = params.expect(user: [ :current_password, :password, :password_confirmation ])
    if attributes[:password].blank?
      current_user.errors.add(:password, :blank)
      current_user.clean_up_passwords
      return render :edit_password, status: :unprocessable_entity
    end

    if current_user.update_with_password(attributes)
      # The new password invalidates every other session; this one is renewed
      # for a week (decision of 2026-11-08).
      sign_in(current_user, force: true)
      redirect_to account_path, notice: t("auth.account.flash.password_updated")
    else
      current_user.clean_up_passwords
      render :edit_password, status: :unprocessable_entity
    end
  end

  private

  # The edit screen says it and the form is replaced by the date; a posted
  # change is refused (the flash would repeat the screen).
  def check_email_change_allowance
    @email_change_blocked_until = current_user.email_change_blocked_until&.in_time_zone(current_user.zone)
  end

  def email_change_rate_limited
    redirect_to edit_email_path, alert: t("devise.failure.rate_limited")
  end
end
