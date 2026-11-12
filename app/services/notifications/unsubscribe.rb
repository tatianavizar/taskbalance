module Notifications
  # One-click unsubscribe (D9, RFC 8058). The link in every notification email
  # carries a signed token naming the person and the event type, so it works
  # without signing in. It can only switch that one type off (and back on):
  # nothing else in the account is reachable with it.
  #
  # The token does not expire: an email stays in an inbox for years. It is
  # bound to its purpose, so a token from another feature (or a tampered one)
  # does not verify.
  module Unsubscribe
    PURPOSE = :notification_unsubscribe

    def self.token_for(user, event_type)
      verifier.generate([ user.id, event_type.to_s ], purpose: PURPOSE)
    end

    # [user, event_type], or nil when the token is forged, damaged, from
    # elsewhere, or names a person or a type that does not exist.
    def self.resolve(token)
      user_id, event_type = verifier.verified(token.to_s, purpose: PURPOSE)
      return unless user_id.is_a?(Integer) && NotificationPreference::EVENT_TYPES.include?(event_type)

      user = User.find_by(id: user_id)
      [ user, event_type ] if user
    end

    def self.verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("notification-unsubscribe"),
        digest: "SHA256", serializer: JSON, url_safe: true
      )
    end
  end
end
