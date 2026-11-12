require "test_helper"

# Lot 10, part A: households of 3 and more (P1 to P8, C14). Every screen that
# shows shares draws one bar per member, the zone moves with the size, and
# the absence question, the gap and the reports hold at 3 and 4.
class LargeHouseholdsTest < ActionDispatch::IntegrationTest
  include WeeklyEngineHelpers
  include SplitHelpers

  setup { travel_to(paris(2026, 11, 4, 18, 32)) }
  teardown { travel_back }

  def assert_page_text(text)
    assert_includes CGI.unescapeHTML(response.body.gsub(/<[^>]+>/, " ")).squish, text
  end

  def log_week!(household, user, count, **options)
    log!(household, user, at: paris(2026, 11, 3, 10), count: count, **options)
  end

  # ---- the rules for N -------------------------------------------------------

  test "fair share is 100 / N rounded and the zone is +/- 10 for 2 to 6 members" do
    { 2 => [ 50, 40..60 ], 3 => [ 33, 23..43 ], 4 => [ 25, 15..35 ], 5 => [ 20, 10..30 ], 6 => [ 17, 7..27 ] }.each do |members, (fair, zone)|
      assert_equal fair, HouseholdRules.fair_share(members), "fair share at #{members}"
      assert_equal zone, HouseholdRules.zone(members), "zone at #{members}"
    end
  end

  test "the zone judges the exact share at three: 43 % is in, 43,6 % is out" do
    household, (a, b, c) = build_household("Ana", "Ben", "Cy")
    log_week!(household, a, 43)
    log_week!(household, b, 28)
    log_week!(household, c, 29)
    stats = WeeklyStats.new(household.reload, household.current_week)
    assert stats.member_for(a).in_zone, "43 % exact is inside 23-43"

    log_week!(household, a, 1) # 44 / 101 = 43,56 %
    stats = WeeklyStats.new(household.reload, household.current_week)
    assert_not stats.member_for(a).in_zone
  end

  # ---- home (P3) -------------------------------------------------------------

  test "P3: the home draws one bar per member with the zone 23-43 at three" do
    household, (virginie, karim, karine) = build_household("Virginie", "Karim", "Karine")
    [ [ virginie, 4 ], [ karim, 3 ], [ karine, 3 ] ].each do |user, count|
      log_week!(household, user, count, mental: true, execution: false)
      log_week!(household, user, count, mental: false, execution: true)
    end
    sign_in virginie

    get dashboard_path

    assert_response :success
    assert_select ".balance-rows", count: 2
    assert_select ".balance-row", count: 6
    assert_select ".balance-zone[style*=?]", "left:23%;width:20%", count: 6
    assert_select ".balance-fair[style*=?]", "calc(33% - 1px)", count: 6
    assert_select "[role=img][aria-label^=?]", "Charge mentale : Virginie 40 %, Karim 30 % et Karine 30 %"
    assert_select "[role=img][aria-label*=?]", "Zone équilibrée : de 23 à 43 %"
    assert_select "[role=img][aria-label*=?]", "Repère de la part juste : 33 %"
  end

  test "P3: out of the zone is said in words and the headline names who carries more" do
    household, (virginie, karim, karine) = build_household("Virginie", "Karim", "Karine")
    log_week!(household, virginie, 8, mental: true, execution: false)
    log_week!(household, karim, 1, mental: true, execution: false)
    log_week!(household, karine, 1, mental: true, execution: false)
    [ virginie, karim, karine ].each { |user| log_week!(household, user, 2, mental: false, execution: true) }
    sign_in karim

    get dashboard_path

    assert_text "Virginie porte 80 % de la charge mentale."
    assert_select ".balance-flag", text: "hors zone", minimum: 2
    assert_select "[role=img][aria-label*=?]", "Hors zone : Karim, Virginie et Karine"
    assert_not response.body.include?("points")
  end

  test "the home at four members has a bar for each and the zone 15-35" do
    household, users = build_household("Ana", "Ben", "Cy", "Dani")
    users.each { |user| log_week!(household, user, 2) }
    sign_in users.first

    get dashboard_path

    assert_select ".balance-row", count: 8
    assert_select ".balance-zone[style*=?]", "left:15%;width:20%", count: 8
    assert_select "[role=img][aria-label*=?]", "Zone équilibrée : de 15 à 35 %"
    assert_select "[role=img][aria-label*=?]", "Repère de la part juste : 25 %"
  end

  test "a paused member leaves the bars: three with one pause is read at two, zone 40-60" do
    household, (a, b, c) = build_household("Ana", "Ben", "Cy")
    MemberPause.declare!(member: membership(household, c), declared_by: a, starts_on: Date.new(2026, 11, 2), ends_on: Date.new(2026, 11, 8))
    log_week!(household, a, 2)
    log_week!(household, b, 2)
    sign_in a

    get dashboard_path

    assert_select ".balance-rows", count: 0
    assert_select "[role=img][aria-label*=?]", "Zone équilibrée : de 40 à 60 %"
  end

  # ---- report (P4) -----------------------------------------------------------

  test "P4: the report has one bar per member at three and names who carries more" do
    household, (virginie, karim, karine) = build_household("Virginie", "Karim", "Karine")
    log_week!(household, virginie, 6)
    log_week!(household, karim, 2)
    log_week!(household, karine, 2)
    sign_in karim

    get report_path

    assert_response :success
    assert_select ".balance-row", count: 6
    assert_select ".balance-zone", count: 6
    assert_page_text "Virginie porte 60 % de la charge mentale"
    assert_select "[role=img][aria-label^=?]", "Charge mentale : Karim 20 %, Virginie 60 % et Karine 20 %"
  end

  test "P4: a stored final report of four members keeps its zone 15-35" do
    household, users = build_household("Ana", "Ben", "Cy", "Dani")
    week = household.current_week.previous
    final_week!(household, week, users[0] => [ 40, 40 ], users[1] => [ 20, 20 ], users[2] => [ 20, 20 ], users[3] => [ 20, 20 ])
    sign_in users[1]

    get report_path(semaine: week.monday.iso8601)

    assert_response :success
    assert_select ".balance-row", count: 8
    assert_select ".balance-zone[style*=?]", "left:15%;width:20%", count: 8
  end

  # ---- absence question (P5) -------------------------------------------------

  def week(n) = Week.containing(Date.new(2026, 10, 5) + (7 * n), PARIS)
  def mid(week) = week.start_at + 2.days + 10.hours

  # Karine logs nothing in weeks 1 and 2: the question is asked of everyone.
  def household_with_inquiry
    household, users = build_household("Virginie", "Karim", "Karine", joined_at: paris(2026, 10, 4, 9))
    users.each { |user| log!(household, user, at: mid(week(0))) }
    users.first(2).each { |user| [ 1, 2 ].each { |n| log!(household, user, at: mid(week(n))) } }
    run_engine(household, HouseholdWeek.final_at(week(2)))
    travel_to(paris(2026, 10, 27, 12))
    [ household, users, household.absence_inquiries.pending.sole ]
  end

  test "P5: at three, everyone is asked, the absent person included, and one Yes declares the pause" do
    household, (virginie, karim, karine), inquiry = household_with_inquiry
    assert_equal 3, inquiry.respondents.size
    sign_in virginie

    get absence_inquiry_path(inquiry)

    assert_response :success
    assert_select "h1", "Absence de Karine ?"
    assert_select "#absence-answers .list-row", count: 3
    assert_page_text "Tout le foyer est interrogé, Karine compris : un seul « Oui » suffit."
    assert_page_text "0 oui · 0 non · 3 sans réponse"

    sign_in karim
    post answer_absence_inquiry_path(inquiry), params: { answer: "no" }
    assert inquiry.reload.pending?
    sign_in virginie
    post answer_absence_inquiry_path(inquiry), params: { answer: "yes" }

    assert inquiry.reload.paused?
    assert_equal membership(household, karine), household.member_pauses.sole.household_member
    sign_in karine
    get absence_inquiry_path(inquiry)
    assert_select "h1", "Une absence de votre part ?"
  end

  test "P5: at three, without a Yes by Wednesday 20:00 the regression applies" do
    household, (virginie, karim, _karine), inquiry = household_with_inquiry
    sign_in karim
    post answer_absence_inquiry_path(inquiry), params: { answer: "no" }
    sign_in virginie
    post answer_absence_inquiry_path(inquiry), params: { answer: "no" }

    run_engine(household, paris(2026, 10, 28, 20))

    assert inquiry.reload.regressed?
    assert household.blocked?
  end

  # ---- split editor (P6, C14, P8) ---------------------------------------------

  def household_with_chores(*names)
    household, users = build_household(*names)
    chores = [ chore!(household, "Faire les courses", users.first(2)),
               chore!(household, "Cuisiner", users.drop(1)),
               chore!(household, "Ménage", users) ]
    [ household, users, chores ]
  end

  test "P6, C14: from three members a task opens a sheet of checkboxes, one button per task shows who carries it" do
    household, (virginie, karim, karine), (shopping, _cooking, _cleaning) = household_with_chores("Virginie", "Karim", "Karine")
    sign_in virginie

    get household_split_path(household)

    assert_response :success
    assert_select "input.assign-input", 0
    assert_select "button.assign-button", count: 3
    assert_select "button.assign-button[aria-haspopup=dialog][aria-label=?]", "Faire les courses : assigné à Virginie et Karim. Modifier"
    assert_select "button.assign-button[aria-label=?]", "Ménage : assigné à Tout le foyer. Modifier" # D6: a label only
    assert_select "dialog#assign_sheet_#{shopping.id}[aria-modal=true][aria-labelledby]" do
      assert_select "h2", "Assigner « Faire les courses »"
      assert_select "input[type=checkbox][name=?]", "assignments[#{shopping.id}][]", count: 3
      assert_select "input[type=checkbox][value=?][checked]", "user:#{virginie.id}"
      assert_select "input[type=checkbox][value=?][checked]", "user:#{karim.id}"
      assert_select "input[type=checkbox][value=?][checked]", "user:#{karine.id}", count: 0
      assert_select "button", text: /Valider · 2 personnes/
      assert_select "fieldset legend", text: /Personnes qui portent/
    end
    assert_select "[role=img][aria-label*=?]", "Zone équilibrée : de 23 à 43 %"
    assert_select ".balance-row", count: 3
    assert_text "Dès 3 membres, on assigne depuis cette liste."
  end

  test "C14: the chips stay at two members" do
    household, (a, _b), _chores = household_with_chores("Ana", "Ben")
    sign_in a

    get household_split_path(household)

    assert_select "input.assign-input", minimum: 4
    assert_select "button.assign-button", 0
  end

  test "P8: « Tout le foyer » is only a label: one assignment per member, each carries the task in full" do
    household, users, (_shopping, _cooking, cleaning) = household_with_chores("Virginie", "Karim", "Karine")
    assert_equal 3, cleaning.reload.assignee_keys.size
    sign_in users.first

    get household_split_path(household)
    assert_select "button.assign-button", text: /Tout le foyer/

    split = PlannedSplit.from_household(household.reload, participants: household.split_participants)
    shares = split.participants.to_h { |p| [ p.user_id, split.share_of(p.key).average ] }
    assert_in_delta 100.0, shares.values.sum, 0.01
    assert_equal users.map(&:id).sort, shares.keys.sort
  end

  test "C14: the live preview and the save take the sheet's checkboxes" do
    household, (virginie, karim, karine), (shopping, cooking, cleaning) = household_with_chores("Virginie", "Karim", "Karine")
    sign_in virginie
    keys = ->(*users) { users.map { |u| "user:#{u.id}" } }
    assignments = { shopping.id => keys.(karine), cooking.id => keys.(karim, karine), cleaning.id => keys.(virginie, karim, karine) }

    post preview_household_split_path(household), params: { assignments: assignments }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=replace][target=planned_bar] .balance-row", count: 3

    patch household_split_path(household), params: { commit_action: "validate", assignments: assignments }
    plan = household.week_plan_for
    assert plan.proposed?
    assert_equal keys.(karine), plan.assignments.find { |i| i["chore_id"] == shopping.id }["assignees"]
  end

  test "C14: a task with nobody ticked is refused, not skipped" do
    household, (virginie, _karim, _karine), (shopping, cooking, cleaning) = household_with_chores("Virginie", "Karim", "Karine")
    sign_in virginie

    patch household_split_path(household), params: { commit_action: "validate",
      assignments: { shopping.id => [ "" ], cooking.id => cooking.assignee_keys, cleaning.id => cleaning.assignee_keys } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]"
  end

  test "the validation waits for each person at three and reads « tous » once everyone validated" do
    household, (virginie, karim, karine), _chores = household_with_chores("Virginie", "Karim", "Karine")
    all = household.chores.active.to_h { |c| [ c.id, c.assignee_keys ] }
    sign_in virginie
    patch household_split_path(household), params: { commit_action: "validate", assignments: all }
    assert_equal "Répartition enregistrée. En attente de Karim et Karine.", flash[:notice]
    [ karim, karine ].each do |user|
      sign_in user
      patch household_split_path(household), params: { commit_action: "validate", assignments: all }
    end
    assert household.week_plan_for.validated?

    get household_split_path(household)
    assert_select ".pill", "Validée par tous"
  end

  # ---- the gap at four ---------------------------------------------------------

  test "the gap at four: real gaps are measured against 25 % and sum to zero" do
    household, users = build_household("Ana", "Ben", "Cy", "Dani")
    chore!(household, "Ménage", users)
    week = household.current_week.previous
    plan!(household, week)
    hw = final_week!(household, week, users[0] => [ 40, 40 ], users[1] => [ 20, 20 ], users[2] => [ 20, 20 ], users[3] => [ 20, 20 ])
    gaps = SplitGap.week_gaps(hw)
    assert_in_delta 15.0, gaps[users[0].id]
    assert_in_delta(-5.0, gaps[users[1].id])
    assert_in_delta 0.0, gaps.values.sum
  end

  # ---- members and colours (P1, P2) ---------------------------------------------

  test "P1: a household takes six people at most, invitations included" do
    household, users = build_household("Ana", "Ben", "Cy", "Dani")
    2.times { |i| Invitation.invite(household: household, email: "new#{i}@example.test", first_name: "N#{i}", inviter: users.first) }
    refused = Invitation.invite(household: household, email: "seventh@example.test", first_name: "Sept", inviter: users.first)
    assert_not refused.persisted?
    assert_includes refused.errors.full_messages.to_sentence, "6"
  end

  test "P1: the household screen lists every member and invitation and invites another person" do
    household, (a, _b, _c) = build_household("Ana", "Ben", "Cy")
    Invitation.invite(household: household, email: "dani@example.test", first_name: "Dani", inviter: a)
    sign_in a

    get household_path(household)

    assert_select ".list-row", text: /Ben/
    assert_select ".list-row", text: /Cy/
    assert_select ".list-row", text: /Dani/
    assert_select "a[href=?]", new_household_invitation_path(household)
  end

  test "D16: colours are unique, handed out in palette order; two initials in common give two letters" do
    household, _users = build_household("Karim", "Karine", "Lou")
    members = household.household_members.order(:id)
    assert_equal %w[mint blue stone], members.pluck(:color)
    assert_equal %w[Km Ke L], members.pluck(:monogram)
  end
end
