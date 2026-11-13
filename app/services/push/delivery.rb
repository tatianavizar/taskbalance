module Push
  # Sends one recorded notification to the person's phones (PushDeliveryJob,
  # at `deliver_at`). The Notifier already decided that it goes out (preference,
  # cap, staleness) and wrote one Notification row with channel "push"; this
  # only carries it, so the cap of D9 holds whatever channel ends up used.
  #
  #   Push::Delivery.call(notification)   # => :pushed, :fell_back, :dropped or :skipped
  #
  #   - not deliverable any more (withdrawn, the person left the household)
  #     -> :skipped, nothing sent (same check as NotificationMailer);
  #   - sent to every reachable device; a device whose token FCM rejects is
  #     deleted (pruned);
  #   - at least one phone got it -> :pushed;
  #   - none did, and one failure is temporary -> RetryLater (the job retries;
  #     after the last attempt it falls back, see `fall_back!`);
  #   - none did otherwise (no device left, push not configured any more,
  #     every token dead, a permanent error) -> `fall_back!`: email when the
  #     Email channel reaches the person (:fell_back), else the row is marked
  #     suppressed "no_channel" (:dropped). The row's channel is rewritten to
  #     what was actually used.
  #
  # What the phone shows: the message title and its first line (the same words
  # as the email, Notifications::Message). Tapping it opens
  # /notifications/:id, which marks it read and redirects to the catalogue
  # target (Notifications::Catalogue, with its path_options).
  class Delivery
    class RetryLater < StandardError; end

    BODY_LIMIT = 240

    def self.call(notification, client: nil)
      new(notification, client: client).call
    end

    # The fallback once retries are exhausted, or when no phone is left.
    def self.fall_back!(notification)
      return :skipped unless notification.deliverable?

      if Notifications::Channels::Email.available_for?(notification.user)
        notification.update_columns(channel: Notifications::Channels::Email::NAME, updated_at: Time.current)
        Notifications::Channels::Email.new.deliver(notification)
        :fell_back
      else
        notification.update_columns(channel: nil, suppressed_reason: "no_channel", updated_at: Time.current)
        :dropped
      end
    end

    def self.payload(notification)
      message = notification.message
      body = Array(message.lines).first.to_s
      {
        notification: { title: message.title.to_s, body: body.truncate(BODY_LIMIT) },
        data: {
          "path" => Rails.application.routes.url_helpers.notification_path(notification),
          "notification_id" => notification.id.to_s,
          "kind" => notification.kind
        }
      }
    end

    def initialize(notification, client: nil)
      @notification = notification
      @client = client
    end

    def call
      return :skipped unless @notification.deliverable? && @notification.channel == Notifications::Channels::Push::NAME

      devices = @notification.user.push_devices.reachable.to_a
      return self.class.fall_back!(@notification) if devices.empty? || !(@client || Fcm.configured?)

      results = devices.map { |device| [ device, send_to(device) ] }
      results.each { |device, result| device.delete if result.invalid_token? }
      return :pushed if results.any? { |_, result| result.ok? }

      results.each { |_, result| report(result) if result.failed? }
      raise RetryLater, results.filter_map { |_, r| r.error if r.retry? }.join("; ") if results.any? { |_, r| r.retry? }

      self.class.fall_back!(@notification)
    end

    private

    def client
      @client ||= Fcm.client
    end

    def send_to(device)
      payload = self.class.payload(@notification)
      client.deliver(token: device.token, notification: payload[:notification], data: payload[:data])
    end

    def report(result)
      Rails.error.report(StandardError.new("FCM: #{result.error}"), handled: true,
                         context: { notification_id: @notification.id })
    end
  end
end
