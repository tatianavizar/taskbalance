# F4: the account screen. First name, email and password each have their own
# screen. The first name needs nothing more than a session; the email and the
# password ask for the current password (a stolen session must not be enough to
# take an account over).
class AccountsController < ApplicationController
  before_action :authenticate_user!

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

  def edit_email
  end

  def update_email
    if current_user.update_with_password(params.expect(user: [ :email, :current_password ]))
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
end
