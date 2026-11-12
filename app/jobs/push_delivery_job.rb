# Carries one notification to the person's phones at its `deliver_at`
# (Notifications::Channels::Push enqueues it). A temporary FCM failure is
# retried; once the attempts are spent, the notification goes by email
# instead (D9: email is the fallback of push).
class PushDeliveryJob < ApplicationJob
  queue_as :default

  retry_on Push::Delivery::RetryLater, wait: :polynomially_longer, attempts: 5 do |job, _error|
    notification = Notification.find_by(id: job.arguments.first)
    Push::Delivery.fall_back!(notification) if notification
  end

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id) or return
    Push::Delivery.call(notification)
  end
end
