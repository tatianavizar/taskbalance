# Account mails that are not Devise's own.
#
# already_registered: sent to an address that tries to sign up although it is
#   already registered. The person who typed it sees the usual success screen;
#   only the owner of the inbox learns that an account exists.
# sign_in_locked: sent to the owner when wrong passwords locked the account
#   (SignInLockout): until when for a temporary lock, whom to write to for the
#   permanent one. The sign-in screen itself never says it.
class AccountMailer < ApplicationMailer
  def already_registered(user)
    @user = user
    @sign_in_url = new_user_session_url
    @reset_password_url = new_user_password_url

    mail(to: user.email, subject: t("account_mailer.already_registered.subject", default: "Vous avez déjà un compte 50/50"))
  end

  def sign_in_locked(user)
    @user = user
    @hard = user.sign_in_hard_locked?
    @attempts = SignInLockout::MAX_FAILED_ATTEMPTS
    @window_hours = (SignInLockout::FAILED_ATTEMPTS_WINDOW / 1.hour).to_i
    @support_email = Mail::Address.new(Rails.configuration.x.mail_from).address
    @reset_password_url = new_user_password_url
    unless @hard
      unlocks_at = (user.sign_in_unlocks_at || Time.current).in_time_zone(user.zone)
      @unlocks_day = I18n.l(unlocks_at.to_date, format: :day_month)
      @unlocks_hour = I18n.l(unlocks_at, format: :hour)
      @lock_hours = (SignInLockout::LOCK_DURATION / 1.hour).to_i
    end

    mail(to: user.email, subject: t("account_mailer.sign_in_locked.subject_#{@hard ? 'hard' : 'temporary'}"))
  end
end
