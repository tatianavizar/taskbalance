require "test_helper"

class MemberPauseTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob")
    @bob_membership = membership(@household, @bob)
  end

  def declare(starts_on, ends_on = nil, by: @alice)
    MemberPause.new(household_member: @bob_membership, declared_by: by, starts_on: starts_on, ends_on: ends_on)
  end

  test "any member can declare a pause for someone else, as many as they want, open-ended or not" do
    travel_to(paris(2026, 10, 20, 9)) do
      assert declare(Date.new(2026, 10, 21), Date.new(2026, 10, 23)).save
      assert declare(Date.new(2026, 11, 2), by: @bob).save
    end
    assert_equal 2, @bob_membership.member_pauses.count
  end

  test "the end cannot come before the start" do
    pause = declare(Date.new(2026, 10, 21), Date.new(2026, 10, 20))
    travel_to(paris(2026, 10, 20, 9)) { assert_not pause.valid? }
    assert pause.errors.added?(:ends_on, :before_start)
  end

  test "a retroactive pause goes back 14 days at most" do
    travel_to(paris(2026, 10, 20, 9)) do
      assert declare(Date.new(2026, 10, 6)).valid?
      too_far = declare(Date.new(2026, 10, 5))
      assert_not too_far.valid?
      assert too_far.errors.added?(:starts_on, :too_far_back, days: 14)
    end
  end

  test "the weeks of an absence inquiry stay eligible beyond 14 days, until the next final report" do
    @household.absence_inquiries.create!(household_member: @bob_membership, first_week_start: Date.new(2026, 9, 28),
                                         last_week_start: Date.new(2026, 10, 5), deadline_at: paris(2026, 10, 14, 20))
    # Window end: the final report of the week of 12 Oct, Monday 19 Oct 03:00.
    travel_to(paris(2026, 10, 19, 2, 59)) { assert declare(Date.new(2026, 9, 28)).valid? }
    travel_to(paris(2026, 10, 19, 3, 0)) { assert_not declare(Date.new(2026, 9, 28)).valid? }
  end

  test "a retroactive pause cannot cover a closed week where the member logged" do
    log!(@household, @bob, at: paris(2026, 10, 7, 9))
    travel_to(paris(2026, 10, 20, 9)) do
      pause = declare(Date.new(2026, 10, 6), Date.new(2026, 10, 18))
      assert_not pause.valid?
      assert_includes pause.errors[:starts_on].first, "Semaine 41"
      assert declare(Date.new(2026, 10, 12)).valid?, "the week after is empty"
    end
  end

  test "logs in the current week do not stop a pause that started earlier this week" do
    log!(@household, @bob, at: paris(2026, 10, 19, 9))
    travel_to(paris(2026, 10, 20, 9)) { assert declare(Date.new(2026, 10, 19)).valid? }
  end

  test "overlapping a week means touching at least one of its days" do
    week = Week.containing(Date.new(2026, 10, 5), PARIS)
    travel_to(paris(2026, 9, 20, 9)) do
      declare(Date.new(2026, 9, 28), Date.new(2026, 10, 4)).save!  # ends the Sunday before
      declare(Date.new(2026, 10, 11), Date.new(2026, 10, 11)).save! # the Sunday only
      declare(Date.new(2026, 10, 12)).save!                         # starts the Monday after
    end

    assert_equal [ Date.new(2026, 10, 11) ], MemberPause.overlapping(week).pluck(:starts_on)
    assert MemberPause.find_by(starts_on: Date.new(2026, 10, 11)).covers?(week)
    assert_not MemberPause.find_by(starts_on: Date.new(2026, 10, 12)).covers?(week)
  end

  test "cancel ends an ongoing pause today and removes a future one" do
    travel_to(paris(2026, 10, 20, 9)) do
      ongoing = declare(Date.new(2026, 10, 19)).tap(&:save!)
      future = declare(Date.new(2026, 11, 2), Date.new(2026, 11, 8)).tap(&:save!)

      ongoing.cancel!
      future.cancel!

      assert_equal Date.new(2026, 10, 20), ongoing.reload.ends_on
      assert_not MemberPause.exists?(future.id)
    end
  end

  test "the reason is shown to the member concerned only" do
    pause = declare(Date.new(2026, 10, 21))
    pause.reason = "Hôpital"
    travel_to(paris(2026, 10, 20, 9)) { pause.save! }

    assert_equal "Hôpital", pause.reason_for(@bob)
    assert_nil pause.reason_for(@alice)
    assert_nil pause.reason_for(nil)
  end

  test "leaving the household removes the member's pauses" do
    travel_to(paris(2026, 10, 20, 9)) { declare(Date.new(2026, 10, 21)).save! }
    @bob_membership.leave!
    assert_equal 0, MemberPause.count
  end
end
