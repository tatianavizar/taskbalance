# A member of the 50/50 team, signing in to the back office (/admin).
# Distinct from User: no relation to a household, no self sign-up. They are
# created by `bin/rails admin:bootstrap` (lib/tasks/admin.rake).
#
# Sign-in always ends with a TOTP code (devise-two-factor). The second factor
# is set up through a one-time enrolment link handed over out of band (printed
# by the rake task), never by the password alone:
#
#   issue_enrolment!  fresh secret + a signed link (30 min), ends every session
#   BackOffice::TwoFactorsController shows the secret only to a session that
#   came through that link AND signed in with the password; the first valid
#   code (`enrol!`) turns the second factor on and uses the link up.
#
# Admins are never destroyed (the audit log points at them): `deactivate!`.
class AdminUser < ApplicationRecord
  # The idle timeout is `timeout_in`; this is the absolute one, from sign-in.
  SESSION_LIFETIME = 8.hours
  ENROLMENT_LINK_VALIDITY = 30.minutes
  PASSWORD_MIN_LENGTH = 12
  # Beyond the length: what people type when told to make a long password.
  COMMON_PASSWORDS = %w[
    password1234 passwordpassword 123456789012 1234567890123 qwertyuiop12 qwertyuiopas
    azertyuiop12 azertyuiopqs administrator adminadmin1234 letmein123456 changemechangeme
    welcome12345 iloveyou1234 cinquante5050 cinquantecinquante 505050505050 admin5050admin
  ].freeze

  devise :two_factor_authenticatable, :lockable, :timeoutable, :validatable,
         password_length: PASSWORD_MIN_LENGTH..128,
         maximum_attempts: 5, unlock_strategy: :time, unlock_in: 30.minutes,
         timeout_in: 30.minutes

  # The audit log is append-only: `restrict`, never `nullify` (that would rewrite rows).
  has_many :admin_actions, dependent: :restrict_with_exception

  generates_token_for :enrolment, expires_in: ENROLMENT_LINK_VALIDITY do
    [ session_version, enrolment_nonce ]
  end

  validate :password_is_not_weak, if: -> { password.present? }

  # Devise keeps this in the session cookie and compares it on every request:
  # bumping `session_version` ends every session of the account.
  def authenticatable_salt
    base = super
    base && "#{base}.#{session_version}"
  end

  def active_for_authentication?
    super && deactivated_at.nil?
  end

  def inactive_message
    deactivated_at ? :invalid : super
  end

  def deactivate!
    update!(deactivated_at: Time.current, session_version: session_version + 1)
  end

  def two_factor_enrolled?
    otp_required_for_login?
  end

  # (Re)starts the enrolment: a brand-new secret, no second factor, every
  # session ended, and a link good for 30 minutes and for one enrolment.
  # Returns the link's token (AdminUser.find_by_token_for(:enrolment, token)).
  def issue_enrolment!
    update!(otp_secret: self.class.generate_otp_secret, consumed_timestep: nil, otp_required_for_login: false,
            enrolment_nonce: SecureRandom.hex(16), session_version: session_version + 1)
    generate_token_for(:enrolment)
  end

  # What an authenticator app scans or opens.
  def provisioning_uri
    otp_provisioning_uri(email, issuer: "50/50 back office")
  end

  # Called with the first code from the app. Turns the second factor on and
  # uses the enrolment link up. False when there is no secret to check.
  def enrol!(code)
    return false if two_factor_enrolled? || otp_secret.blank? || !validate_and_consume_otp!(code)

    update!(otp_required_for_login: true, enrolment_nonce: nil, failed_attempts: 0)
  end

  # A wrong enrolment code counts like a wrong password (Devise lockable).
  # Returns true when this attempt locked the account.
  def register_failed_enrolment!
    increment_failed_attempts
    return false unless attempts_exceeded?

    lock_access!
    true
  end

  # Lost phone: `bin/rails admin:reset_two_factor`.
  def reset_two_factor!
    issue_enrolment!
  end

  private

  def password_is_not_weak
    local_part = email.to_s.split("@").first.to_s.downcase
    if password.chars.uniq.size < 5
      errors.add(:password, "est trop répétitif")
    elsif COMMON_PASSWORDS.include?(password.downcase)
      errors.add(:password, "est trop courant")
    elsif local_part.length >= 4 && password.downcase.include?(local_part)
      errors.add(:password, "ne doit pas contenir l'email")
    end
  end
end
