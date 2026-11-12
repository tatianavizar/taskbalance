require "test_helper"

class MemberPauseTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob")
    @bob_membership = membership(@household, @bob)
  end

  def declare(starts_on, ends_on = nil, by: @bob)
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
      assert_equal "Vous avez déjà enregistré une tâche en semaine 41 : la pause peut commencer lundi 12 octobre.",
                   pause.errors[:starts_on].first
      assert declare(Date.new(2026, 10, 12)).valid?, "the week after is empty"
    end
  end

  test "a pause cannot cover the current week once the member logged in it, even for one day or from tomorrow" do
    log!(@household, @bob, at: paris(2026, 10, 19, 9))
    travel_to(paris(2026, 10, 20, 9)) do
      [ Date.new(2026, 10, 19), Date.new(2026, 10, 20), Date.new(2026, 10, 25) ].each do |sunday_or_earlier|
        pause = declare(sunday_or_earlier, sunday_or_earlier)
        assert_not pause.valid?, "#{sunday_or_earlier} is in the logged week"
      end
      pause = declare(Date.new(2026, 10, 22))
      assert_not pause.valid?
      assert_equal "Vous avez déjà enregistré une tâche cette semaine : la pause peut commencer lundi 26 octobre.",
                   pause.errors[:starts_on].first
      assert declare(Date.new(2026, 10, 26)).valid?, "the following Monday is free"
    end
  end

  test "a log in an earlier week only matters for the weeks the pause touches" do
    log!(@household, @bob, at: paris(2026, 10, 14, 9))
    travel_to(paris(2026, 10, 20, 9)) do
      assert declare(Date.new(2026, 10, 19), Date.new(2026, 10, 25)).valid?
      assert_not declare(Date.new(2026, 10, 18), Date.new(2026, 10, 25)).valid?, "the Sunday belongs to the logged week"
    end
  end

  test "the message names the person when someone else declares the pause (F8)" do
    open_inquiry
    log!(@household, @bob, at: paris(2026, 10, 7, 9))
    travel_to(paris(2026, 10, 20, 9)) do
      pause = declare(Date.new(2026, 10, 5), Date.new(2026, 10, 18), by: @alice)
      assert_not pause.valid?
      assert_equal "Bob a déjà enregistré une tâche en semaine 41 : la pause peut commencer lundi 12 octobre.",
                   pause.errors[:starts_on].first
    end
  end

  test "extending a pause over a week with a log is refused, within the same week it is not" do
    travel_to(paris(2026, 10, 19, 9)) { @pause = declare(Date.new(2026, 10, 19), Date.new(2026, 10, 20)).tap(&:save!) }
    log!(@household, @bob, at: paris(2026, 10, 22, 9)) # logged during the pause's own week
    travel_to(paris(2026, 10, 23, 9)) do
      @pause.ends_on = Date.new(2026, 10, 24)
      assert @pause.valid?, "no new week is covered"
      @pause.ends_on = Date.new(2026, 10, 27)
      assert @pause.valid?, "next week is empty"
    end
    log!(@household, @bob, at: paris(2026, 10, 28, 9))
    travel_to(paris(2026, 10, 29, 9)) do
      @pause.ends_on = Date.new(2026, 11, 1)
      assert_not @pause.valid?
      assert_equal "Vous avez déjà enregistré une tâche cette semaine : la pause peut commencer lundi 2 novembre.",
                   @pause.errors[:ends_on].first
    end
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

  # ---- F8: a pause for someone else is bounded -------------------------------------

  def open_inquiry
    @household.absence_inquiries.create!(household_member: @bob_membership, first_week_start: Date.new(2026, 10, 5),
                                         last_week_start: Date.new(2026, 10, 12), deadline_at: paris(2026, 10, 21, 20))
  end

  test "a pause declared for someone else needs an end date" do
    open_inquiry
    travel_to(paris(2026, 10, 20, 9)) do
      pause = declare(Date.new(2026, 10, 5), nil, by: @alice)
      assert_not pause.valid?
      assert pause.errors.added?(:ends_on, :required_for_someone_else)
    end
  end

  test "a pause declared for someone else stays in the weeks of the open inquiry, Monday to Sunday" do
    open_inquiry
    travel_to(paris(2026, 10, 20, 9)) do
      assert declare(Date.new(2026, 10, 5), Date.new(2026, 10, 18), by: @alice).valid?
      assert_not declare(Date.new(2026, 10, 4), Date.new(2026, 10, 18), by: @alice).valid?
      assert_not declare(Date.new(2026, 10, 5), Date.new(2026, 10, 19), by: @alice).valid?
      assert_not declare(Date.new(2026, 10, 20), Date.new(2026, 10, 25), by: @alice).valid?
    end
  end

  test "without an open inquiry or regression, nothing can be declared for someone else" do
    travel_to(paris(2026, 10, 20, 9)) do
      pause = declare(Date.new(2026, 10, 19), Date.new(2026, 10, 20), by: @alice)
      assert_not pause.valid?
      assert pause.errors.added?(:base, :outside_inquiry_weeks)
    end
  end

  # ---- extending a pause -----------------------------------------------------------

  test "a finished pause cannot be edited" do
    travel_to(paris(2026, 10, 14, 9)) { @pause = declare(Date.new(2026, 10, 12), Date.new(2026, 10, 13)).tap(&:save!) }
    travel_to(paris(2026, 10, 20, 9)) { assert_not @pause.editable? }
    travel_to(paris(2026, 10, 13, 9)) { assert @pause.editable? }
  end

  test "extending a pause over a closed week is refused" do
    travel_to(paris(2026, 10, 14, 9)) { @pause = declare(Date.new(2026, 10, 12), Date.new(2026, 10, 13)).tap(&:save!) }
    travel_to(paris(2026, 10, 27, 9)) do
      @pause.ends_on = Date.new(2026, 10, 25)
      assert_not @pause.valid?
      assert @pause.errors.added?(:ends_on, :closed_weeks_need_declaration)
    end
  end

  test "extending a pause over a closed week where the member logged is refused with the same message as a creation" do
    log!(@household, @bob, at: paris(2026, 10, 14, 9))
    travel_to(paris(2026, 10, 10, 9)) { @pause = declare(Date.new(2026, 10, 9), Date.new(2026, 10, 11)).tap(&:save!) }
    travel_to(paris(2026, 10, 20, 9)) do
      @pause.ends_on = Date.new(2026, 10, 18)
      assert_not @pause.valid?
      assert_equal "Vous avez déjà enregistré une tâche en semaine 42 : la pause peut commencer lundi 19 octobre.",
                   @pause.errors[:ends_on].first
    end
  end

  test "extending a current pause into the future is allowed and announces the new dates" do
    travel_to(paris(2026, 10, 20, 9)) do
      pause = declare(Date.new(2026, 10, 19), Date.new(2026, 10, 21)).tap(&:save!)
      pause.update!(ends_on: Date.new(2026, 10, 30))

      assert_equal 1, @household.engine_events.where(name: "member_pause.updated").count
      assert_equal "2026-10-30", @household.engine_events.find_by(name: "member_pause.updated").payload["ends_on"]
      Notifications::Dispatcher.deliver_pending(@household)
      assert_equal 2, Notification.where(kind: "pause_declared").distinct.count(:dedup_key)
    end
  end
end
