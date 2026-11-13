module BackOffice
  # What the rake tasks (lib/tasks/admin.rake) do to back-office accounts.
  # Each writes an AdminAction with the actor "console", and hands back the
  # one-time enrolment link when a second factor has to be set up: it is the
  # only way the secret reaches a person (the enrolment page shows it only to
  # a session that came through that link).
  class Console
    Result = Data.define(:admin, :created, :enrolment_token) do
      def enrolment_issued? = enrolment_token.present?
    end

    class Invalid < StandardError; end

    class << self
      # Creates the account, or resets the password of an existing one (ending
      # its sessions: the password is part of the session salt). The second
      # factor is left alone when already set up.
      def bootstrap(email:, password:)
        admin = AdminUser.find_or_initialize_by(email: email.to_s.strip.downcase)
        created = admin.new_record?
        admin.password = admin.password_confirmation = password

        AdminUser.transaction do
          raise Invalid, admin.errors.full_messages.to_sentence unless admin.save

          admin.unlock_access! if admin.access_locked?
          token = admin.issue_enrolment! unless admin.two_factor_enrolled?
          AdminAction.record_console!(action: created ? "admin.bootstrapped" : "admin.password_reset", record: admin,
                                      enrolment_link_issued: token.present?)
          Result.new(admin: admin, created: created, enrolment_token: token)
        end
      end

      # Lost phone: a new secret, a new link, every session of the admin ended.
      def reset_two_factor(email:)
        admin = AdminUser.find_by(email: email.to_s.strip.downcase) or raise Invalid, "No back-office account for that email."

        AdminUser.transaction do
          token = admin.reset_two_factor!
          AdminAction.record_console!(action: "admin.two_factor_reset", record: admin)
          Result.new(admin: admin, created: false, enrolment_token: token)
        end
      end

      def enrolment_url(token)
        Rails.application.routes.url_helpers.back_office_two_factor_link_url(
          token: token, host: ENV.fetch("APP_HOST", "localhost:3000"), protocol: Rails.env.production? ? "https" : "http"
        )
      end
    end
  end
end
