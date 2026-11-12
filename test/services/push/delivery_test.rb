require "test_helper"

# D9 with push: push first, email as the fallback, one cap across channels.
class PushDeliveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
  include WeeklyEngineHelpers
  include PushHelpers

  class AlertEvent < Notifications::Event
    KIND = "alert_no_logs".freeze

    def initialize(household, key:, at:, kind: KIND)
      super(household)
      @key = key
      @at = at
      @kind = kind
    end

    def kind = @kind
    def deliver_at = @at
    def key_parts = [ @key ]

    def facts
      {
        "subject" => { "user_id" => 0, "first_name" => "Karim" }, "week_number" => 45,
        "week_start" => "2026-11-02", "week_end" => "2026-11-08",
        "counts" => [ { "user_id" => 0, "first_name" => "Karim", "logs_count" => 0 } ], "recent" => []
      }
    end
  end

  setup do
    @household, (@virginie, @karim) = build_household("Virginie", "Karim")
    @now = Time.current
  end

  def phone!(user, token: "token-#{SecureRandom.hex(4)}", platform: "ios", seen: @now)
    PushDevice.register!(user, token: token, platform: platform, now: seen)
  end

  # Runs the push jobs, retries included (they are scheduled later).
  def drain_push_jobs
    10.times do
      break if enqueued_jobs.none? { |job| job[:job] == PushDeliveryJob }

      perform_enqueued_jobs(only: PushDeliveryJob)
    end
  end

  def alert(key = "a", kind: "alert_no_logs") = AlertEvent.new(@household, key: key, at: @now, kind: kind)

  def notify(event, to: [ @virginie ]) = Notifications::Notifier.call(event, to: to, now: @now)

  # ---- choosing the channel ---------------------------------------------------

  test "without FCM credentials, a person with a phone still gets email" do
    phone!(@virginie)

    assert_enqueued_emails 1 do
      assert_equal "email", notify(alert).first.channel
    end
  end

  test "with FCM and a phone, the notification goes by push, not by email" do
    phone!(@virginie, token: "virginie-phone")

    with_fcm do |transport|
      notification = nil
      assert_no_enqueued_emails do
        assert_enqueued_with(job: PushDeliveryJob) { notification = notify(alert).first }
      end
      assert_equal "push", notification.channel

      perform_enqueued_jobs
      message = transport.sent_messages.sole
      assert_equal "virginie-phone", message["token"]
      assert_equal "/notifications/#{notification.id}", message.dig("data", "path")
      assert_equal notification.message.title, message.dig("notification", "title")
      assert_equal notification.message.lines.first, message.dig("notification", "body")
    end
  end

  test "a person without a phone, or with a phone silent for too long, gets email" do
    phone!(@karim, seen: @now - PushDevice::STALE_AFTER - 1.day)

    with_fcm do
      assert_enqueued_emails 2 do
        notifications = notify(alert, to: [ @virginie, @karim ])
        assert_equal %w[email email], notifications.map(&:channel)
      end
    end
  end

  test "every reachable phone of the person gets it" do
    phone!(@virginie, platform: "ios")
    phone!(@virginie, platform: "android")

    with_fcm do |transport|
      notify(alert)
      perform_enqueued_jobs
      assert_equal 2, transport.sends.size
    end
  end

  # ---- cap, preferences ---------------------------------------------------------

  test "the weekly cap counts push and email together" do
    phone!(@virginie)

    with_fcm do
      first = notify(alert("first")).first
      PushDevice.where(user: @virginie).delete_all
      second = notify(alert("second")).first

      assert_equal "push", first.channel
      assert_nil second.channel
      assert_equal "cap", second.suppressed_reason
    end
  end

  test "a type switched off sends nothing, on any channel" do
    phone!(@virginie)
    NotificationPreference.set(@virginie, "alert", false)

    with_fcm do |transport|
      assert_no_enqueued_jobs(only: PushDeliveryJob) { notify(alert) }
      assert_empty transport.sends
    end
  end

  # ---- dead tokens and fallback -----------------------------------------------------

  test "a token FCM no longer knows is pruned, and the message falls back on email" do
    device = phone!(@virginie)

    with_fcm(PushHelpers::FakeTransport.new([ fcm_error(404, "NOT_FOUND", error_code: "UNREGISTERED") ])) do
      notification = notify(alert).first
      perform_enqueued_jobs(only: PushDeliveryJob)

      assert_not PushDevice.exists?(device.id)
      assert_equal "email", notification.reload.channel
      assert_enqueued_emails 1
    end
  end

  test "one dead phone among two: the live one gets it, no email" do
    dead = phone!(@virginie, token: "dead")
    phone!(@virginie, token: "alive")
    transport = PushHelpers::FakeTransport.new
    def transport.call(url, headers:, body:)
      return super unless body.include?('"token":"dead"')

      @requests << PushHelpers::FakeTransport::Request.new(url, headers, body)
      [ 404, JSON.generate(error: { status: "NOT_FOUND", details: [ { errorCode: "UNREGISTERED" } ] }) ]
    end

    with_fcm(transport) do
      notification = notify(alert).first
      perform_enqueued_jobs(only: PushDeliveryJob)

      assert_not PushDevice.exists?(dead.id)
      assert_equal "push", notification.reload.channel
      assert_no_enqueued_emails
    end
  end

  test "a temporary failure is retried, then falls back on email once the attempts are spent" do
    phone!(@virginie)

    with_fcm(PushHelpers::FakeTransport.new([ fcm_error(503, "UNAVAILABLE") ])) do |transport|
      notification = notify(alert).first
      drain_push_jobs

      assert_equal 5, transport.sends.size
      assert_equal "email", notification.reload.channel
      assert_enqueued_emails 1
      assert PushDevice.exists?(user: @virginie), "a busy FCM does not prune the phone"
    end
  end

  test "a permanent error falls back on email without retrying" do
    phone!(@virginie)

    with_fcm(PushHelpers::FakeTransport.new([ fcm_error(400, "INVALID_ARGUMENT", message: "Invalid JSON payload") ])) do |transport|
      notification = notify(alert).first
      perform_enqueued_jobs(only: PushDeliveryJob)

      assert_equal 1, transport.sends.size
      assert_equal "email", notification.reload.channel
    end
  end

  test "no fallback address: the notification is recorded as reaching nobody" do
    phone!(@virginie)
    @virginie.update_columns(confirmed_at: nil)

    with_fcm(PushHelpers::FakeTransport.new([ fcm_error(404, "NOT_FOUND", error_code: "UNREGISTERED") ])) do
      notification = notify(alert).first
      perform_enqueued_jobs(only: PushDeliveryJob)

      assert_nil notification.reload.channel
      assert_equal "no_channel", notification.suppressed_reason
      assert_no_enqueued_emails
    end
  end

  test "nothing goes to a person who left the household before the sending time" do
    phone!(@karim)

    with_fcm do |transport|
      notification = Notifications::Notifier.call(AlertEvent.new(@household, key: "later", at: @now + 1.hour), to: [ @karim ], now: @now).first
      membership(@household, @karim).leave!
      travel 2.hours do
        perform_enqueued_jobs(only: PushDeliveryJob)
      end

      assert_empty transport.sends
      assert_equal "departed", notification.reload.suppressed_reason
    end
  end

  test "the push waits for the delivery time of the notification" do
    phone!(@virginie)

    with_fcm do
      at = @now + 3.hours
      assert_enqueued_with(job: PushDeliveryJob, at: at) do
        Notifications::Notifier.call(AlertEvent.new(@household, key: "monday", at: at), to: [ @virginie ], now: @now)
      end
    end
  end
end
