# Loaded first (00_) because the Devise initializer reads the sender.
# Outgoing mail configuration. The SMTP provider is not chosen yet, so nothing
# is hard-coded: each setting is read from the ENV first, then from the
# `smtp:` section of the encrypted credentials.
#
#   SMTP_ADDRESS, SMTP_PORT (587), SMTP_USER_NAME, SMTP_PASSWORD,
#   SMTP_DOMAIN, SMTP_AUTHENTICATION (plain), SMTP_ENABLE_STARTTLS (true)
#   MAIL_FROM  sender, default "50/50 <bonjour@cinquante.app>"
#   APP_HOST   host used in the links of the emails (see production.rb)
module MailSettings
  DEFAULT_FROM = "50/50 <bonjour@cinquante.app>".freeze

  def self.from
    ENV["MAIL_FROM"].presence || DEFAULT_FROM
  end

  def self.smtp(env: ENV, credentials: Rails.application.credentials.fetch(:smtp, {}))
    pick = ->(key) { env["SMTP_#{key.upcase}"].presence || credentials[key.to_sym].presence }

    {
      address: pick.("address"),
      port: (pick.("port") || 587).to_i,
      domain: pick.("domain"),
      user_name: pick.("user_name"),
      password: pick.("password"),
      authentication: (pick.("authentication") || "plain").to_sym,
      enable_starttls_auto: pick.("enable_starttls").to_s != "false"
    }.compact
  end
end

Rails.application.config.x.mail_from = MailSettings.from

if Rails.env.production?
  Rails.application.config.action_mailer.smtp_settings = MailSettings.smtp
end
