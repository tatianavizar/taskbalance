require "test_helper"

class NotificationsNotifierTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include WeeklyEngineHelpers

  # A weekly report or an alert for the household, with a controllable
  # delivery time and key.
  class FakeEvent < Notifications::Event
    KIND = "alert_no_logs".freeze

    def initialize(household, key:, at:, kind: KIND)
      super(household)
      @key = key
      @at = at
      @kind = kind
    end

    def kind = @kind
    def deliver_at = @at
    def facts = { "who" => "test" }
    def key_parts = [ @key ]
  end

  # A channel standing in for lot 8b's push: always reachable.
  class FakePush
    NAME = "push".freeze
    DELIVERED = []
    def self.available_for?(_user) = true
    def deliver(notification) = DELIVERED << notification.id
  end

  setup do
    @household, (@virginie, @karim) = build_household("Virginie", "Karim")
    @monday = paris(2026, 11, 9, 8)
    FakePush::DELIVERED.clear
  end

  def with_channels(*channels)
    original = Notifications::Channels.registry
    Notifications::Channels.registry = channels
    yield
  ensure
    Notifications::Channels.registry = original
  end

  def event(key, at: @monday, kind: "alert_no_logs") = FakeEvent.new(@household, key: key, at: at, kind: kind)
  def notify(event, **options) = Notifications::Notifier.call(event, now: @monday, **options)

  test "an event goes by email to every member and is recorded" do
    assert_enqueued_emails 2 do
      notifications = notify(event("a"))
      assert_equal [ @virginie.id, @karim.id ].sort, notifications.map(&:user_id).sort
      assert(notifications.all? { |n| n.channel == "email" && n.dispatched_at && n.suppressed_reason.nil? })
    end
  end

  # ---- preferences ----------------------------------------------------------

  test "a person who switched the type off gets nothing, and it stays out of their feed" do
    NotificationPreference.set(@karim, "alert", false)

    assert_enqueued_emails 1 do
      notify(event("a"))
    end

    karim = Notification.find_by!(user: @karim)
    assert_equal "preference", karim.suppressed_reason
    assert_nil karim.channel
    assert_empty Notification.where(user: @karim).feed
    assert_equal 1, Notification.where(user: @virginie).feed.count
  end

  test "switching one type off leaves the others on" do
    NotificationPreference.set(@karim, "alert", false)

    assert_enqueued_emails 2 do
      notify(event("report", kind: "weekly_report"))
    end
  end

  test "the defaults are all on, and a setting is per type" do
    assert_equal NotificationPreference::EVENT_TYPES.index_with(true), NotificationPreference.settings_for(@karim)
    NotificationPreference.set(@karim, "monday_split", false)
    assert_not NotificationPreference.enabled?(@karim, "monday_split")
    assert NotificationPreference.enabled?(@karim, "weekly_report")
    assert NotificationPreference.enabled?(@virginie, "monday_split")
  end

  test "pauses and their outcome follow the absence question setting, the gap reset and « Prêt » the Monday split" do
    assert_equal "absence_question", Notifications::Catalogue.fetch("pause_declared").event_type
    assert_equal "absence_question", Notifications::Catalogue.fetch("absence_outcome").event_type
    assert_equal "monday_split", Notifications::Catalogue.fetch("gap_reset").event_type
    assert_equal "monday_split", Notifications::Catalogue.fetch("household_ready").event_type
    assert_equal NotificationPreference::EVENT_TYPES.sort, Notifications::Catalogue::ENTRIES.values.map(&:event_type).uniq.sort
  end

  test "an unconfirmed address gets nothing" do
    @karim.update_columns(confirmed_at: nil)

    assert_enqueued_emails 1 do
      notify(event("a"))
    end
    assert_equal "no_channel", Notification.find_by!(user: @karim).suppressed_reason
  end

  test "an event that came due more than two days ago is recorded but not sent" do
    assert_no_enqueued_emails do
      Notifications::Notifier.call(event("old", at: @monday - 3.days), now: @monday)
    end
    assert_equal %w[stale stale], Notification.where(household: @household).pluck(:suppressed_reason)
  end

  # ---- the weekly cap -------------------------------------------------------

  test "a second alert in the same week is not sent, but stays in the feed" do
    notify(event("first"))

    assert_no_enqueued_emails do
      notify(event("second", at: @monday + 2.days))
    end

    second = Notification.where(user: @virginie, dedup_key: event("second").dedup_key).sole
    assert_equal "cap", second.suppressed_reason
    assert_nil second.channel
    assert_equal 2, Notification.where(user: @virginie).feed.count
  end

  test "the next week has its own alert" do
    notify(event("first"))

    assert_enqueued_emails 2 do
      notify(event("next week", at: @monday + 7.days))
    end
  end

  test "one report and one alert in the same week do not compete" do
    notify(event("alert"))

    assert_enqueued_emails 2 do
      notify(event("report", kind: "weekly_report"))
    end
  end

  test "events without a cap class are never capped" do
    assert_enqueued_emails 6 do
      3.times { |i| notify(event("task #{i}", kind: "task_assigned")) }
    end
  end

  test "the cap counts every channel: an alert already pushed uses the week's alert" do
    Notification.create!(user: @karim, household: @household, kind: "alert_blocked", event_type: "alert", cap_class: "alert",
                         dedup_key: "pushed", facts: {}, channel: "push", cap_week_start: Date.new(2026, 11, 9), deliver_at: @monday)

    assert_enqueued_emails 1 do
      notify(event("second"))
    end
    assert_equal "cap", Notification.find_by!(user: @karim, dedup_key: event("second").dedup_key).suppressed_reason
  end

  test "the cap week is the household's local week, not UTC" do
    # Monday 00:30 in Paris is still Sunday 23:30 in UTC: the cap week is the Paris one.
    notify(event("a", at: paris(2026, 11, 9, 0, 30)))
    assert_equal Date.new(2026, 11, 9), Notification.where(user: @karim).sole.cap_week_start
  end

  test "the database refuses two sent alerts for one person and week" do
    notify(event("first"))
    duplicate = Notification.where(user: @karim).sole.dup.tap { _1.dedup_key = "other" }

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  # ---- idempotence ----------------------------------------------------------

  test "the same event twice is sent once" do
    assert_enqueued_emails 2 do
      notify(event("same"))
      notify(event("same"))
    end
    assert_equal 2, Notification.where(household: @household).count
  end

  test "an event suppressed once is not retried when the person changes their setting" do
    NotificationPreference.set(@karim, "alert", false)
    notify(event("same"))
    NotificationPreference.set(@karim, "alert", true)

    assert_enqueued_emails 0 do
      notify(event("same"))
    end
  end

  test "the same weekly report built twice is sent once" do
    week = @household.household_weeks.create!(WeeklyStats.new(@household, Week.containing(paris(2026, 11, 3), PARIS)).to_snapshot.merge(status: "provisional", computed_at: @monday))

    assert_enqueued_emails 2 do
      2.times { Notifications::Notifier.call(Notifications::Events::WeeklyReport.new(week), now: @monday) }
    end
  end

  # ---- adding a channel -----------------------------------------------------

  test "a new channel is picked first without changing the Notifier" do
    with_channels(FakePush, Notifications::Channels::Email) do
      assert_no_enqueued_emails do
        notifications = notify(event("pushed"))
        assert_equal [ "push" ], notifications.map(&:channel).uniq
      end
    end
    assert_equal 2, FakePush::DELIVERED.size
  end

  test "email stays the fallback when the first channel does not reach the person" do
    unreachable = Class.new(FakePush) do
      const_set(:NAME, "push")
      def self.available_for?(_user) = false
    end

    with_channels(unreachable, Notifications::Channels::Email) do
      assert_enqueued_emails 2 do
        assert_equal [ "email" ], notify(event("fallback")).map(&:channel).uniq
      end
    end
  end

  # ---- scope: to ------------------------------------------------------------

  test "the recipients can be narrowed" do
    assert_enqueued_emails 1 do
      assert_equal [ @karim.id ], notify(event("only karim"), to: [ @karim ]).map(&:user_id)
    end
  end
end
