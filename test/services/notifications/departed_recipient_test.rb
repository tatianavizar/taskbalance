require "test_helper"

# The engine writes the report and alerts at 03:00 and they go out at 08:00. A
# member who leaves in between must get neither.
class NotificationsDepartedRecipientTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers
  include ActionMailer::TestHelper

  setup do
    travel_to paris(2026, 11, 16, 3, 5) # Monday, after the close
    @household, (@ann, @ben) = build_household("Ann", "Ben")
    [ @ann, @ben ].each { |user| user.update_columns(confirmed_at: Time.current) }
  end

  def notification!(user, kind: "weekly_report", household: @household, deliver_at: paris(2026, 11, 16, 8), dedup: kind)
    Notification.create!(user: user, household: household, kind: kind,
                         event_type: Notifications::Catalogue.fetch(kind).event_type,
                         dedup_key: "#{dedup}:#{user.id}", facts: { "household_name" => "Chez nous", "week_number" => 46 },
                         channel: "email", deliver_at: deliver_at)
  end

  test "the mailer sends nothing to someone who is no longer a member of the household" do
    report = notification!(@ann)
    HouseholdMember.where(user_id: @ann.id).delete_all # left without HouseholdDeparture

    assert_not report.reload.deliverable?
    assert_no_emails { NotificationMailer.notify(report).deliver_now }
  end

  test "a current member still receives it" do
    report = notification!(@ben, kind: "reengagement")

    assert report.deliverable?
    assert_emails(1) { NotificationMailer.notify(report).deliver_now }
  end

  test "leaving withdraws the leaver's notifications that are not due yet, nobody else's" do
    ann_report = notification!(@ann, kind: "reengagement")
    ann_past = notification!(@ann, kind: "alert_no_logs", deliver_at: 1.hour.ago, dedup: "past")
    ben_report = notification!(@ben, kind: "reengagement")

    membership(@household, @ann).leave!

    ann_report.reload
    assert_equal "departed", ann_report.suppressed_reason
    assert_nil ann_report.channel
    assert_nil ann_past.reload.suppressed_reason
    assert_nil ben_report.reload.suppressed_reason

    travel_to paris(2026, 11, 16, 9) do
      assert_not_includes Notification.where(user_id: @ann.id).feed, ann_report
      assert_no_emails { NotificationMailer.notify(ann_report).deliver_now }
    end
  end
end
