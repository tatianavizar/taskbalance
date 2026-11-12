module Notifications
  module Channels
    # Lot 8b (D9): first choice when the person has a phone that accepted
    # notifications (a reachable PushDevice) and FCM is configured. Delivery,
    # pruning of dead tokens and the fallback on email are in Push::Delivery.
    class Push
      NAME = "push".freeze

      def self.available_for?(user)
        ::Push::Fcm.configured? && user.push_devices.reachable.exists?
      end

      def deliver(notification)
        PushDeliveryJob.set(wait_until: notification.deliver_at).perform_later(notification.id)
      end
    end
  end
end
