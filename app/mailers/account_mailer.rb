# "You already have an account": sent to an address that tries to sign up
# although it is already registered. The person who typed it sees the usual
# success screen; only the owner of the inbox learns that an account exists.
class AccountMailer < ApplicationMailer
  def already_registered(user)
    @user = user
    @sign_in_url = new_user_session_url
    @reset_password_url = new_user_password_url

    mail(to: user.email, subject: t("account_mailer.already_registered.subject", default: "Vous avez déjà un compte 50/50"))
  end
end
