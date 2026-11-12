module BackOffice
  # Sign-ins, refused sign-ins and lockouts go to the audit log (AdminAction).
  # Called from the Warden hooks in config/initializers/two_factor.rb. A
  # failure to write the log never blocks the sign-in flow itself: it is
  # reported and the request goes on.
  module SignInAudit
    module_function

    def signed_in(admin, env)
      AdminAction.record!(admin: admin, action: "admin.signed_in", record: admin,
                          two_factor: admin.two_factor_enrolled?, ip: ip(env))
    rescue StandardError => e
      Rails.error.report(e, handled: true)
    end

    # Only an attempt on the sign-in form counts (not a visit to /admin without
    # a session). `locked` is its own action: the account is out of reach.
    def failed(env, opts)
      request = ActionDispatch::Request.new(env)
      return unless request.post? && request.path == Rails.application.routes.url_helpers.admin_user_session_path

      email = request.params.dig("admin_user", "email").to_s
      admin = AdminUser.find_by(email: email.strip.downcase) if email.present?
      reason = opts[:message].to_s
      AdminAction.record_event!(action: reason == "locked" ? "admin.locked" : "admin.sign_in_failed", email: email,
                                admin: admin, record: admin, reason: reason.presence || "invalid", ip: ip(env))
    rescue StandardError => e
      Rails.error.report(e, handled: true)
    end

    def ip(env)
      ActionDispatch::Request.new(env).remote_ip
    end
  end
end
