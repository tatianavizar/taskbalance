require "test_helper"

module Households
  class SplitsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @household = households(:smith_home)
      @alice = users(:alice)
      @bob = users(:bob)
      sign_in @alice
      @cooking = chores(:smith_cooking)
    end

    def assignments(overrides = {})
      @household.chores.active.to_h { |c| [ c.id, c.assignee_keys ] }.merge(overrides)
    end

    test "C4: the planned bar, one chip per person and the frequency of each task" do
      get household_split_path(@household)

      assert_response :success
      assert_select "h2", "Prévu cette semaine"
      assert_select "[role=img][aria-label*=?]", "Part juste : 50 %"
      assert_select "input.assign-input[name=?]", "assignments[#{@cooking.id}][]", count: 2
      assert_select "input.assign-input[name=?][value=?][checked]", "assignments[#{@cooking.id}][]", "user:#{@alice.id}"
      assert_text "Exécution · 45 min · chaque jour"
      assert_text "Exécution · 60 min · 3 fois par semaine"
    end

    test "C8: when the tasks cannot make 50/50, it says the real gap is carried over" do
      get household_split_path(@household)
      assert_text "Pas de 50/50 pile avec ces tâches. L'écart réel de la semaine sera reporté."
    end

    test "validating proposes the week plan and waits for the others" do
      patch household_split_path(@household), params: { commit_action: "validate", assignments: assignments }

      plan = @household.week_plan_for
      assert plan.proposed?
      assert plan.approved_by?(@alice)
      assert_equal "Répartition enregistrée. En attente de Bob.", flash[:notice]

      get household_path(@household)
      assert_text "En attente de Bob"
    end

    test "the other member validating the split as it is validates it for everyone" do
      WeekPlan.propose!(household: @household, by: @alice)
      sign_in @bob

      patch household_split_path(@household), params: { commit_action: "validate", assignments: assignments }

      plan = @household.week_plan_for
      assert plan.validated?
      assert_equal "Répartition validée.", flash[:notice]

      get household_split_path(@household)
      assert_select ".pill", "Validée par tous les deux"
      assert_select "input.assign-input", 0
      assert_text "Validée par tous. Elle reste fixe jusqu'à lundi"
    end

    test "an edit by the other member asks the first again" do
      WeekPlan.propose!(household: @household, by: @alice)
      sign_in @bob

      patch household_split_path(@household), params: { commit_action: "validate", assignments: assignments(@cooking.id => [ "user:#{@bob.id}" ]) }

      plan = @household.week_plan_for
      assert plan.proposed?
      assert_equal [ "Alice" ], plan.pending_participants.map(&:first_name)
      assert_equal [ "user:#{@bob.id}" ], @cooking.reload.assignee_keys
    end

    test "a validated split cannot change before Monday" do
      plan = WeekPlan.propose!(household: @household, by: @alice)
      plan.approve!(by: @bob)

      patch household_split_path(@household), params: { commit_action: "validate", assignments: assignments(@cooking.id => [ "user:#{@bob.id}" ]) }

      assert_redirected_to household_split_path(@household)
      assert_equal [ "user:#{@alice.id}" ], @cooking.reload.assignee_keys
    end

    test "a task left without anyone is refused, nothing is written" do
      patch household_split_path(@household), params: { commit_action: "validate", assignments: assignments(@cooking.id => [ "" ]) }

      assert_response :unprocessable_entity
      assert_select ".alert-box", "Assignez la tâche à au moins une personne."
      assert_nil @household.week_plan_for
      assert_equal [ "user:#{@alice.id}" ], @cooking.reload.assignee_keys
    end

    test "a task can be shared: it counts in full for each" do
      patch household_split_path(@household), params: { commit_action: "recompute", assignments: { @cooking.id => [ "user:#{@alice.id}", "user:#{@bob.id}" ] } }

      assert_redirected_to household_split_path(@household, mode: "now")
      assert_equal 2, @cooking.reload.chore_assignees.count
      assert_nil @household.week_plan_for, "recomputing does not propose"
    end

    test "a person or a chore from another household is refused" do
      patch household_split_path(@household), params: { commit_action: "recompute", assignments: { @cooking.id => [ "user:#{users(:carol).id}" ] } }
      assert_response :unprocessable_entity

      jones = chores(:jones_cooking)
      patch household_split_path(@household), params: { commit_action: "recompute", assignments: { jones.id => [ "user:#{@alice.id}" ] } }
      assert_equal [ "user:#{users(:carol).id}" ], jones.reload.assignee_keys
    end

    test "another household's split is not reachable" do
      get household_split_path(households(:jones_home))
      assert_response :not_found
    end

    test "approve validates the split as it is" do
      WeekPlan.propose!(household: @household, by: @alice)
      sign_in @bob

      post approve_household_split_path(@household)

      assert @household.week_plan_for.validated?
    end
  end
end
