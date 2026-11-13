require "test_helper"

# Lot 6 screens: live shares (preview), out-of-zone warning, C9 gap reset,
# D15/D16 handovers, D11 home card.
class WeeklySplitScreensTest < ActionDispatch::IntegrationTest
  include WeeklyEngineHelpers
  include SplitHelpers

  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
    @bob = users(:bob)
    @cooking = chores(:smith_cooking)
    sign_in @alice
  end

  def assignments(overrides = {})
    @household.chores.active.to_h { |c| [ c.id, c.assignee_keys ] }.merge(overrides)
  end

  def everything_to(user) = assignments.transform_values { [ "user:#{user.id}" ] }

  # ---- live shares ------------------------------------------------------------

  test "preview answers a Turbo Stream with the recomputed bar and saves nothing" do
    before = ChoreAssignee.order(:id).pluck(:chore_id, :user_id)

    post preview_household_split_path(@household), params: { assignments: everything_to(@bob) },
                                                   headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(<turbo-stream action="replace" target="planned_bar">)
    assert_includes response.body, "<b>0 %</b> Alice"
    assert_includes response.body, "Bob <b>100 %</b>"
    assert_equal before, ChoreAssignee.order(:id).pluck(:chore_id, :user_id), "no assignee written"
    assert_nil @household.week_plan_for, "no plan proposed"
    assert_equal 0, Approval.count
  end

  test "validating still persists the assignments and proposes the plan" do
    patch household_split_path(@household), params: { commit_action: "validate", assignments: assignments(@cooking.id => [ "user:#{@bob.id}" ]) }

    assert_equal [ "user:#{@bob.id}" ], @cooking.reload.assignee_keys
    assert @household.week_plan_for.proposed?
  end

  test "the editor is wired for live shares, the old button stays as the fallback" do
    get household_split_path(@household)
    assert_select "form[data-controller=split-preview][data-split-preview-url-value=?]", preview_household_split_path(@household)
    assert_select "button[value=recompute][data-split-preview-target=fallback]"
    assert_select "#planned_bar"
  end

  test "no preview on a locked plan" do
    plan = WeekPlan.propose!(household: @household, by: @alice)
    plan.approve!(by: @bob)
    post preview_household_split_path(@household), params: { assignments: assignments }
    assert_response :conflict
  end

  # ---- out of the zone --------------------------------------------------------

  test "an out-of-zone split is saved with a warning; the one above the zone may not carry the gap" do
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }

    plan = @household.week_plan_for
    assert plan.proposed?, "saved, not blocked"
    assert_equal "Répartition hors de la zone 40–60 % : Alice 100 % et Bob 0 %. L'écart de cette semaine ne sera pas reporté.",
                 flash[:alert]
    assert_not plan.carry_gap
    assert_equal @alice, plan.gap_waived_by
  end

  test "the member below the zone cannot waive the gap" do
    sign_in @bob
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }

    assert @household.week_plan_for.carry_gap
    assert_includes flash[:alert], "L'écart réel de la semaine sera reporté."
  end

  # ---- the waiver does not survive edits --------------------------------------------

  test "a waiver is dropped when the split is edited: the author no longer carries the surplus" do
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }
    assert_not @household.week_plan_for.carry_gap

    sign_in @bob
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@bob) }

    plan = @household.week_plan_for
    assert plan.carry_gap, "the gap is carried again"
    assert_nil plan.gap_waived_by
    assert_not plan.gap_waiver_valid?
  end

  test "the author edits to a split where they are below the zone and asks again: still refused" do
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@bob), carry_gap: "0" }

    plan = @household.week_plan_for
    assert plan.carry_gap
    assert_nil plan.gap_waived_by
  end

  test "the author re-waives on an edit that keeps them above the zone: the waiver stands" do
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }

    assert_equal @alice, @household.week_plan_for.gap_waived_by
  end

  test "the approval screen tells the others that the gap is waived, and at whose request" do
    patch household_split_path(@household), params: { commit_action: "validate", assignments: everything_to(@alice), carry_gap: "0" }

    sign_in @bob
    get household_split_path(@household)
    assert_text "L'écart de cette semaine ne sera pas reporté, à la demande de Alice."
  end

  # ---- C9 gap -------------------------------------------------------------------

  def carried!(amount)
    week = @household.current_week
    @household.split_gap_entries.create!(kind: :week, week_start: week.previous.monday, user: @alice, amount: amount)
    @household.split_gap_entries.create!(kind: :week, week_start: week.previous.monday, user: @bob, amount: -amount)
  end

  test "C9: the gap names who carried more; only that member gets the reset button" do
    carried!(7)
    get household_split_path(@household)
    assert_text "Vous avez porté 7 % de plus que votre part."
    assert_select "form[action=?]", reset_gap_household_split_path(@household)

    sign_in @bob
    get household_split_path(@household)
    assert_text "Alice a porté 7 % de plus que sa part."
    assert_select "form[action=?]", reset_gap_household_split_path(@household), count: 0
    post reset_gap_household_split_path(@household)
    assert_equal "Seule la personne qui a porté le surplus peut remettre l'écart à zéro.", flash[:alert]
    assert_in_delta 7.0, SplitGap.balance_of(@household, @alice)
  end

  test "C9: the reset zeroes the gap and tells the other member" do
    carried!(7)
    post reset_gap_household_split_path(@household)

    assert_equal "Écart remis à zéro. Les autres membres sont prévenus.", flash[:notice]
    assert_equal({ @alice.id => 0.0, @bob.id => 0.0 }, SplitGap.balances(@household))
    assert_equal [ @bob.id ], Notification.where(kind: "gap_reset").pluck(:user_id)
  end

  # ---- D15 / D16 ----------------------------------------------------------------

  test "D15 then D16: Alice offers a task, Bob accepts it for the week" do
    plan = WeekPlan.propose!(household: @household, by: @alice)
    plan.approve!(by: @bob)

    get new_household_handover_path(@household)
    assert_response :success
    assert_select "select[name='handover[to_user_id]'] option", text: "Bob"

    post household_handovers_path(@household), params: { handover: { chore_id: @cooking.id, to_user_id: @bob.id } }
    handover = TaskHandover.last
    assert_redirected_to household_handover_path(@household, handover)

    sign_in @bob
    get household_handover_path(@household, handover)
    assert_text "Si vous acceptez, « Cook a meal » est prévue dans votre charge mentale cette semaine."
    post accept_household_handover_path(@household, handover)
    assert handover.reload.accepted?
    assert_equal [ "user:#{@alice.id}" ], @cooking.reload.assignee_keys, "the validated split does not change"
  end

  test "someone outside the household cannot see an offer" do
    plan = WeekPlan.propose!(household: @household, by: @alice)
    plan.approve!(by: @bob)
    handover = TaskHandover.offer!(chore: @cooking, from: @alice, to: @bob)

    sign_in users(:carol)
    get household_handover_path(@household, handover)
    assert_response :not_found
  end

  # ---- D11 ----------------------------------------------------------------------

  test "D11: the home card shows the plan in two states and my planned share" do
    WeekPlan.propose!(household: @household, by: @bob)
    get dashboard_path
    assert_text "Répartition de la semaine #{@household.current_week.number}"
    assert_text "En attente de Alice"
    assert_select "a[href=?]", household_split_path(@household), text: "Voir et valider"
    assert_match(/Prévu pour vous : \d+ %/, response.body)
  end
end
