require "test_helper"

# The set-up checklist: Foyer → Partenaire → Tâches → Répartition, resumed
# where it was left (« Mise en place 2 sur 4 »).
module Households
  class SetupFlowTest < ActionDispatch::IntegrationTest
    setup do
      @dana = users(:dana)
      sign_in @dana
    end

    def create_household
      post households_path, params: { household: { name: "Chez Dana" } }
      Household.find_by!(name: "Chez Dana")
    end

    test "a new household resumes at step 2, the partner" do
      household = create_household
      assert_redirected_to household_setup_path(household)
      follow_redirect!
      assert_select "[role=group][aria-label=?]", "Étape 2 sur 4"
      assert_select "h1", "Avec qui partagez-vous le foyer ?"

      get dashboard_path
      assert_select "a[href=?]", household_setup_path(household), text: /Mise en place 2 sur 4/
    end

    test "skipping the partner step goes to the tasks (C1), with the regular tasks ticked" do
      household = create_household
      patch household_setup_path(household)
      assert_equal "tasks", household.reload.setup_step
      follow_redirect!
      assert_redirected_to household_chores_setup_path(household)
      follow_redirect!

      assert_select "h1", "Ce que votre foyer fait"
      assert_select "input[type=checkbox][name='task_ids[]'][value=?][checked]", tasks(:cook_meal).id.to_s
      assert_select "input[type=checkbox][name='task_ids[]'][value=?]:not([checked])", tasks(:do_laundry).id.to_s
      assert_select "input[type=submit][value=?]", "Continuer avec 2 tâches"
    end

    test "choosing the tasks creates chores with the catalogue defaults, assigned, then opens the split" do
      household = create_household
      household.update!(setup_step: "tasks")

      patch household_chores_setup_path(household), params: { task_ids: [ tasks(:cook_meal).id, tasks(:pay_bills).id ] }

      assert_redirected_to household_setup_path(household)
      assert_equal "split", household.reload.setup_step
      cooking = household.chores.find_by!(task: tasks(:cook_meal))
      assert cooking.daily?
      assert cooking.execution_load
      assert_equal 45, cooking.time_required
      assert_equal @dana, cooking.created_by
      assert_equal [ "user:#{@dana.id}" ], cooking.assignee_keys
      assert household.chores.find_by!(task: tasks(:pay_bills)).monthly?
    end

    test "the set-up needs at least one task" do
      household = create_household
      household.update!(setup_step: "tasks")

      patch household_chores_setup_path(household), params: { task_ids: [ "" ] }

      assert_response :unprocessable_entity
      assert_equal "tasks", household.reload.setup_step
    end

    test "alone, validating the split ends the set-up and validates it at once" do
      household = create_household
      household.update!(setup_step: "tasks")
      patch household_chores_setup_path(household), params: { task_ids: [ tasks(:cook_meal).id ] }
      chore = household.chores.first

      get household_split_path(household)
      assert_response :success
      assert_select "[role=group][aria-label=?]", "Étape 4 sur 4"

      patch household_split_path(household), params: { commit_action: "validate", assignments: { chore.id => [ "", "user:#{@dana.id}" ] } }

      assert_redirected_to dashboard_path
      assert household.reload.setup_done?
      plan = household.starting_plan
      assert plan.starting?
      assert plan.validated?
      assert_equal "Répartition validée.", flash[:notice]
    end

    test "with someone invited, the split step asks to wait or go ahead (C12)" do
      household = create_household
      household.invitations.create!(email: "karim@example.com")
      household.update!(setup_step: "split")
      household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @dana.id ])

      get household_split_path(household)
      assert_redirected_to choice_household_split_path(household)
      follow_redirect!
      assert_select "h1", "karim n'a pas encore rejoint"
      assert_select "a.choice-card[href=?]", household_split_path(household, mode: "now")
      assert_select "button.choice-card", /Attendre karim/

      get household_split_path(household, mode: "now")
      assert_response :success
      assert_text "Provisoire : elle sera recalculée quand karim aura rejoint"
      assert_select "input.assign-input[value=?]", "invitation:#{household.invitations.first.id}"
    end

    test "« Attendre » ends the set-up without a split" do
      household = create_household
      household.invitations.create!(email: "karim@example.com")
      household.update!(setup_step: "split")

      post wait_household_split_path(household)

      assert_redirected_to dashboard_path
      assert household.reload.setup_done?
      assert household.starting_plan.awaiting_proposal?
    end

    test "« Proposer maintenant » counts the invited person and waits for them (D15)" do
      household = create_household
      invitation = household.invitations.create!(email: "karim@example.com")
      household.update!(setup_step: "split")
      chore = household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @dana.id ])

      patch household_split_path(household), params: { commit_action: "validate", assignments: { chore.id => [ "invitation:#{invitation.id}" ] } }

      plan = household.reload.starting_plan
      assert plan.proposed?
      assert plan.provisional?
      assert_equal "Répartition enregistrée. En attente de karim.", flash[:notice]
    end
  end
end
