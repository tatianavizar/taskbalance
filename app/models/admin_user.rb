# A member of the 50/50 team, signing in to the back office (/admin).
# Distinct from User: no relation to a household, no self sign-up. They are
# created by `bin/rails admin:bootstrap` (lib/tasks/admin.rake).
#
# Sign-in always ends with a TOTP code (devise-two-factor). A new account has
# `otp_required_for_login` false: it can sign in with the password alone, but
# the back office refuses everything except the enrolment page
# (BackOffice::TwoFactorsController) until a first code proves the secret was
# scanned. After that the code is part of every sign-in.
class AdminUser < ApplicationRecord
  devise :two_factor_authenticatable, :lockable, :timeoutable, :validatable,
         password_length: 12..128,
         maximum_attempts: 5, unlock_strategy: :time, unlock_in: 30.minutes,
         timeout_in: 30.minutes

  has_many :admin_actions, dependent: :nullify

  def two_factor_enrolled?
    otp_required_for_login?
  end

  # The secret waiting for its first code. Made once and kept, so a reload of
  # the enrolment page shows the same one.
  def ensure_otp_secret!
    update!(otp_secret: self.class.generate_otp_secret) if otp_secret.blank?
    otp_secret
  end

  # What an authenticator app scans or opens.
  def provisioning_uri
    otp_provisioning_uri(email, issuer: "50/50 back office")
  end

  # Called with the first code from the app. Turns the second factor on.
  def enrol!(code)
    return false if two_factor_enrolled? || !validate_and_consume_otp!(code)

    update!(otp_required_for_login: true)
  end

  # Starts over (lost phone): `bin/rails admin:reset_two_factor`.
  def reset_two_factor!
    update!(otp_secret: nil, consumed_timestep: nil, otp_required_for_login: false)
  end
end
