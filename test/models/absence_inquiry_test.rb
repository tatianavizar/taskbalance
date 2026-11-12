require "test_helper"

class AbsenceInquiryTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  Refused = AbsenceInquiry::AnswerRefused

  def week(n, zone = PARIS) = Week.containing(Date.new(2026, 10, 5) + (7 * n), zone)
  def mid(week) = week.start_at + 2.days + 10.hours

  # Everyone logs in week 0; only the first member logs in weeks 1 and 2, so
  # every other member has an inquiry from Monday 26 Oct 03:00 (local), with
  # its deadline on Wednesday 28 Oct 20:00 (local).
  def household_with_inquiry(*names, zone: PARIS, absent: names.drop(1))
    household, users = build_household(*names, zone: zone, joined_at: local(zone, 2026, 10, 4, 9))
    users.each { |u| log!(household, u, at: mid(week(0, zone))) }
    present = users.reject { |u| absent.include?(u.first_name) }
    [ 1, 2 ].each { |n| present.each { |u| log!(household, u, at: mid(week(n, zone))) } }
    run_engine(household, HouseholdWeek.final_at(week(2, zone)))
    [ household, *users ]
  end

  def inquiry_about(household, user)
    household.absence_inquiries.find_by!(household_member: membership(household, user))
  end

  def answer(inquiry, user, value, at: paris(2026, 10, 27, 12))
    travel_to(at) { inquiry.answer!(by: user, value: value, at: at) }
  end

  def correct(inquiry, answer, user, value, at: paris(2026, 10, 27, 13))
    travel_to(at) { inquiry.correct!(answer, by: user, value: value, at: at) }
  end

  def events(household, name) = household.engine_events.where(name: name).chronological

  # ---- two members ---------------------------------------------------------

  test "opening: everyone is asked, nobody has answered, an event is recorded" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)

    assert_equal "Bob", inquiry.concerned_first_name
    assert_equal [ alice.id, bob.id ], inquiry.respondents.map(&:user_id)
    assert_equal [ alice.id, bob.id ], inquiry.unanswered_members.map(&:user_id)
    assert_equal({ yes: 0, no: 0, unanswered: 2 }, inquiry.answers_summary)
    assert_equal paris(2026, 10, 28, 20), inquiry.deadline_at
    assert_equal :awaiting_answers, inquiry.current_outcome(paris(2026, 10, 27, 9))
    assert inquiry.can_answer?(alice, paris(2026, 10, 27, 9))
    assert inquiry.can_answer?(bob, paris(2026, 10, 27, 9)), "the absent member answers too"
    assert_not inquiry.can_answer?(users(:carol), paris(2026, 10, 27, 9))
    assert_equal [ inquiry ], AbsenceInquiry.awaiting_answer_from(alice, paris(2026, 10, 27, 9)).to_a
    assert_equal [ inquiry ], AbsenceInquiry.open_for(household, paris(2026, 10, 27, 9)).to_a

    opened = events(household, "absence_inquiry.opened").sole
    assert_equal inquiry, opened.subject
    assert_equal({ "user_id" => bob.id, "first_name" => "Bob", "first_week_start" => "2026-10-12",
                   "last_week_start" => "2026-10-19" }, opened.payload.slice("user_id", "first_name", "first_week_start", "last_week_start"))
    assert_nil opened.delivered_at
  end

  test "two 'No' answers are recorded; at the deadline the regression applies" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)

    answer(inquiry, alice, "no")
    assert_equal [ bob.id ], inquiry.reload.unanswered_members.map(&:user_id)
    assert_equal [ inquiry.id ], AbsenceInquiry.awaiting_answer_from(bob, paris(2026, 10, 27, 12)).ids
    assert_empty AbsenceInquiry.awaiting_answer_from(alice, paris(2026, 10, 27, 12))
    answer(inquiry, bob, "no")

    inquiry.reload
    assert inquiry.pending?
    assert_equal({ yes: 0, no: 2, unanswered: 0 }, inquiry.answers_summary)
    assert_equal :regression_due, inquiry.current_outcome(paris(2026, 10, 28, 20))
    assert_empty household.reload.member_pauses

    run_engine(household, paris(2026, 10, 28, 20))
    assert inquiry.reload.regressed?
    assert household.blocked?
    assert_equal :regressed, inquiry.current_outcome
    assert_equal [ "no", "no" ], events(household, "absence_answer.given").map { _1.payload["answer"] }
    assert_equal "regressed", events(household, "absence_inquiry.resolved").sole.payload["outcome"]
  end

  test "the absent member's own 'Yes' declares the pause at once; no regression at the deadline" do
    household, _alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)

    given = answer(inquiry, bob, "yes")
    inquiry.reload
    assert inquiry.paused?
    assert_equal :away_declared, inquiry.current_outcome
    pause = given.reload.member_pause
    assert_equal [ bob.id, Date.new(2026, 10, 12), Date.new(2026, 10, 25) ], [ pause.declared_by_id, pause.starts_on, pause.ends_on ]
    assert_equal "paused", events(household, "absence_inquiry.resolved").sole.payload["outcome"]
    assert inquiry.accepting_answers?(paris(2026, 10, 27, 12)), "the others can still answer until the deadline"

    run_engine(household, paris(2026, 10, 29, 9))
    assert_not household.blocked?
    assert_equal 1, household.level
  end

  test "answering again replaces the answer; the same answer twice changes nothing" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)

    answer(inquiry, alice, "no")
    answer(inquiry, alice, "no", at: paris(2026, 10, 27, 14))
    assert_equal 1, inquiry.absence_answers.count
    assert_equal 1, events(household, "absence_answer.given").count

    answer(inquiry, alice, "yes", at: paris(2026, 10, 27, 15))
    answer(inquiry, alice, "yes", at: paris(2026, 10, 27, 16))
    assert_equal 1, inquiry.absence_answers.count
    assert_equal 1, household.reload.member_pauses.count
    assert inquiry.reload.paused?
    assert_equal [ false, true ], events(household, "absence_answer.given").map { _1.payload["changed"] }

    run_engine(household, paris(2026, 10, 29, 9))
    run_engine(household, paris(2026, 10, 29, 9))
    assert_equal 1, events(household, "absence_inquiry.opened").count
    assert_equal 1, events(household, "absence_inquiry.resolved").count
  end

  test "the author changing a 'Yes' to 'No' withdraws the pause when no other 'Yes' is left" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)
    answer(inquiry, alice, "yes")
    assert_equal 2, household.week_corrections.count

    answer(inquiry, alice, "no", at: paris(2026, 10, 27, 14))
    inquiry.reload
    assert inquiry.pending?
    assert_empty household.reload.member_pauses
    assert_empty household.week_corrections
    assert_equal 2, membership(household, bob).empty_weeks_streak
    assert_equal "reopened", events(household, "absence_inquiry.resolved").last.payload["outcome"]
  end

  # ---- corrections by the member concerned ---------------------------------

  test "the member concerned corrects a 'Yes' made about them: the pause goes, the regression applies" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)
    given = answer(inquiry, alice, "yes")
    assert inquiry.can_correct?(given, bob, paris(2026, 10, 27, 13))
    assert_equal [ given ], inquiry.reload.correctable_answers(bob, paris(2026, 10, 27, 13))

    corrected = correct(inquiry, given, bob, "no")
    assert_equal [ "no", "yes" ], [ corrected.answer, corrected.original_answer ]
    assert corrected.corrected?
    assert_nil corrected.member_pause_id
    assert inquiry.reload.pending?
    assert_empty household.reload.member_pauses
    assert_empty household.week_corrections
    assert_equal 2, membership(household, bob).empty_weeks_streak
    assert household.warned?

    event = events(household, "absence_answer.corrected").sole
    assert_equal({ "original_answer" => "yes", "answer" => "no", "corrected_by_user_id" => bob.id },
                 event.payload.slice("original_answer", "answer", "corrected_by_user_id"))

    run_engine(household, paris(2026, 10, 28, 20))
    assert household.blocked?
  end

  test "the member concerned corrects a 'No' made about them: the pause is declared, by them" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)
    given = answer(inquiry, alice, "no")

    correct(inquiry, given, bob, "yes")
    assert inquiry.reload.paused?
    assert_equal bob.id, household.reload.member_pauses.sole.declared_by_id
    assert_equal "no", given.reload.original_answer

    correct(inquiry, given, bob, "no", at: paris(2026, 10, 27, 14))
    assert_equal "no", given.reload.original_answer, "the respondent's own word is kept"
    assert inquiry.reload.pending?
  end

  test "only the member concerned corrects, and only answers made by someone else" do
    household, alice, bob, chloe = household_with_inquiry("Alice", "Bob", "Chloé", absent: [ "Bob" ])
    inquiry = inquiry_about(household, bob)
    alices = answer(inquiry, alice, "yes")
    bobs = answer(inquiry, bob, "no")

    error = assert_raises(Refused) { correct(inquiry, alices, chloe, "no") }
    assert_equal :not_concerned, error.reason
    assert_equal :not_correctable, assert_raises(Refused) { correct(inquiry, bobs, bob, "yes") }.reason
    assert_not inquiry.can_correct?(bobs, bob, paris(2026, 10, 27, 13))
    assert_equal [ alices ], inquiry.reload.correctable_answers(bob, paris(2026, 10, 27, 13))
  end

  # ---- three members and more -----------------------------------------------

  test "three members: one 'Yes' among 'No' answers is enough; later 'Yes' answers join the same pause" do
    household, alice, bob, chloe = household_with_inquiry("Alice", "Bob", "Chloé", absent: [ "Bob" ])
    inquiry = inquiry_about(household, bob)
    assert_equal 3, inquiry.respondents.size

    answer(inquiry, alice, "no")
    answer(inquiry, chloe, "yes", at: paris(2026, 10, 27, 13))
    assert inquiry.reload.paused?
    assert_equal chloe.id, household.reload.member_pauses.sole.declared_by_id

    answer(inquiry, alice, "yes", at: paris(2026, 10, 27, 14))
    assert_equal 1, household.reload.member_pauses.count
    assert_equal({ yes: 2, no: 0, unanswered: 1 }, inquiry.reload.answers_summary)
    assert_equal [ bob.id ], inquiry.unanswered_members.map(&:user_id)
  end

  test "three members: correcting one 'Yes' keeps the pause while another 'Yes' stands" do
    household, alice, bob, chloe = household_with_inquiry("Alice", "Bob", "Chloé", absent: [ "Bob" ])
    inquiry = inquiry_about(household, bob)
    alices = answer(inquiry, alice, "yes")
    chloes = answer(inquiry, chloe, "yes", at: paris(2026, 10, 27, 12, 30))
    pause = alices.reload.member_pause

    correct(inquiry, alices, bob, "no")
    assert inquiry.reload.paused?
    assert_equal pause, chloes.reload.member_pause, "the pause now hangs on the remaining 'Yes'"
    assert_nil alices.reload.member_pause

    correct(inquiry, chloes, bob, "no", at: paris(2026, 10, 27, 14))
    assert inquiry.reload.pending?
    assert_not MemberPause.exists?(pause.id)
  end

  test "four members, two absent: each inquiry has its own answers" do
    household, alice, bob, chloe, dan = household_with_inquiry("Alice", "Bob", "Chloé", "Dan", absent: [ "Bob", "Chloé" ])
    about_bob = inquiry_about(household, bob)
    about_chloe = inquiry_about(household, chloe)

    answer(about_bob, dan, "yes")
    answer(about_chloe, alice, "no")
    assert about_bob.reload.paused?
    assert about_chloe.reload.pending?
    assert_equal [ about_chloe.id ], AbsenceInquiry.awaiting_answer_from(dan, paris(2026, 10, 27, 12)).ids

    run_engine(household, paris(2026, 10, 28, 20))
    assert household.blocked?, "Chloé's inquiry had no 'Yes'"
    assert about_chloe.reload.regressed?
    assert about_bob.reload.paused?
  end

  # ---- deadline, zones, refusals -------------------------------------------

  test "deadline in a non-Paris zone: answers until Wednesday 19:59:59 local, refused at 20:00" do
    zone = "America/New_York"
    household, alice, bob = household_with_inquiry("Alice", "Bob", zone: zone)
    inquiry = inquiry_about(household, bob)
    deadline = local(zone, 2026, 10, 28, 20)
    assert_equal deadline, inquiry.deadline_at
    assert_equal Time.utc(2026, 10, 29, 0, 0), deadline

    answer(inquiry, alice, "no", at: deadline - 1.second)
    assert inquiry.accepting_answers?(deadline - 1.second)
    assert_not inquiry.accepting_answers?(deadline)
    assert_equal :closed, assert_raises(Refused) { answer(inquiry, bob, "yes", at: deadline) }.reason
    assert_not inquiry.can_answer?(bob, deadline)
    assert_empty household.reload.member_pauses

    run_engine(household, deadline - 1.second)
    assert inquiry.reload.pending?
    run_engine(household, deadline)
    assert inquiry.reload.regressed?
  end

  test "a 'Yes' one second before the deadline (non-Paris zone) avoids the regression" do
    zone = "Asia/Kolkata"
    household, alice, bob = household_with_inquiry("Alice", "Bob", zone: zone)
    inquiry = inquiry_about(household, bob)
    deadline = local(zone, 2026, 10, 28, 20)

    answer(inquiry, alice, "yes", at: deadline - 1.second)
    run_engine(household, deadline + 1.hour)
    assert inquiry.reload.paused?
    assert_not household.blocked?
  end

  test "late answers and corrections are refused, also once the inquiry is resolved" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)
    given = answer(inquiry, alice, "no")
    run_engine(household, paris(2026, 10, 28, 20))

    assert_equal :closed, assert_raises(Refused) { answer(inquiry, bob, "yes", at: paris(2026, 10, 28, 21)) }.reason
    assert_equal :closed, assert_raises(Refused) { correct(inquiry, given, bob, "yes", at: paris(2026, 10, 28, 21)) }.reason
    assert_equal :closed, assert_raises(Refused) { answer(inquiry, bob, "yes", at: paris(2026, 10, 27, 9)) }.reason,
                 "a regressed inquiry takes no more answers"
    assert_empty AbsenceInquiry.open_for(household, paris(2026, 10, 27, 9))
  end

  test "an outsider or an unknown value is refused" do
    household, _alice, bob = household_with_inquiry("Alice", "Bob")
    inquiry = inquiry_about(household, bob)

    assert_equal :not_a_member, assert_raises(Refused) { answer(inquiry, users(:carol), "yes") }.reason
    assert_equal :not_a_member, assert_raises(Refused) { answer(inquiry, nil, "yes") }.reason
    assert_equal :invalid_answer, assert_raises(Refused) { answer(inquiry, bob, "maybe") }.reason
    assert_empty inquiry.absence_answers
  end

  test "the outbox: undelivered events in order, marked once delivered" do
    household, alice, bob = household_with_inquiry("Alice", "Bob")
    answer(inquiry_about(household, bob), alice, "yes")

    names = household.engine_events.undelivered.map(&:name)
    assert_equal %w[absence_inquiry.opened absence_answer.given absence_inquiry.resolved], names
    household.engine_events.first.mark_delivered!
    assert_equal 2, household.engine_events.undelivered.count
  end
end
