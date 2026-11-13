# Active Record encryption keys. Today they protect one thing: the TOTP
# secret of back-office accounts (AdminUser#otp_secret, devise-two-factor).
#
# Production: set ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY, ..._DETERMINISTIC_KEY and
# ..._KEY_DERIVATION_SALT (or `active_record_encryption` in the credentials),
# generated once with `bin/rails db:encryption:init`, and never change them: a
# secret encrypted with other keys cannot be read back. Without them nothing
# fails at boot (the Docker build precompiles assets without secrets); the first
# read or write of a TOTP secret raises ActiveRecord::Encryption::Errors::Configuration.
#
# Development and test use fixed throw-away keys.
credentials = Rails.application.credentials.active_record_encryption || {}
keys = {
  primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] || credentials[:primary_key],
  deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] || credentials[:deterministic_key],
  key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] || credentials[:key_derivation_salt]
}

if Rails.env.local?
  keys[:primary_key] ||= "50-50-development-primary-key-0001"
  keys[:deterministic_key] ||= "50-50-development-deterministic-0001"
  keys[:key_derivation_salt] ||= "50-50-development-key-derivation-salt"
end

Rails.application.config.active_record.encryption.tap do |encryption|
  keys.each { |name, value| encryption[name] = value if value.present? }
end
