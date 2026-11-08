require "test_helper"

class MailSettingsTest < ActiveSupport::TestCase
  test "the sender defaults to 50/50 and is shared by Devise and ApplicationMailer" do
    assert_equal "50/50 <bonjour@cinquante.app>", MailSettings::DEFAULT_FROM
    assert_equal Rails.configuration.x.mail_from, Devise.mailer_sender
    assert_equal Rails.configuration.x.mail_from, InvitationMailer.default[:from].call
  end

  test "SMTP settings come from the ENV, then from credentials, with no hard-coded value" do
    settings = MailSettings.smtp(env: { "SMTP_ADDRESS" => "smtp.env.test", "SMTP_PORT" => "2525" },
                                 credentials: { address: "smtp.cred.test", user_name: "mailer" })

    assert_equal "smtp.env.test", settings[:address]
    assert_equal 2525, settings[:port]
    assert_equal "mailer", settings[:user_name]
    assert_equal :plain, settings[:authentication]
    assert_not settings.key?(:password)
  end

  test "without any setting the SMTP hash only carries the protocol defaults" do
    assert_equal({ port: 587, authentication: :plain, enable_starttls_auto: true },
                 MailSettings.smtp(env: {}, credentials: {}))
  end
end
