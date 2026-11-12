module Notifications
  module Channels
    class Email
      NAME = "email".freeze

      # An address nobody confirmed may be a typo: nothing about a household's
      # balance goes there.
      def self.available_for?(user)
        user.email.present? && user.confirmed?
      end

      def deliver(notification)
        NotificationMailer.notify(notification).deliver_later(wait_until: notification.deliver_at)
      end
    end
  end
end
