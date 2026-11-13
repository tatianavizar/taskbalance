require "test_helper"

class ChoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
    @household = households(:smith_home)
  end

  # --- new ---

  test "new uses the user's own household when household_id is missing" do
    get new_chore_path
    assert_response :success
  end

  test "new redirects to households when the user has no household" do
    sign_in users(:dana)
    get new_chore_path
    assert_redirected_to households_path
  end

  test "new renders form when household_id is valid" do
    get new_chore_path, params: { household_id: @household.id }
    assert_response :success
  end

  test "new redirects when household belongs to another user" do
    other_household = households(:jones_home)
    # alice is also in jones_home per fixtures — test with a household she's NOT in
    # Create a household alice doesn't belong to
    stranger_household = Household.create!(name: "Stranger Home")
    get new_chore_path, params: { household_id: stranger_household.id }
    assert_redirected_to households_path
  ensure
    stranger_household&.destroy
  end

  # --- create: custom chore ---

  def custom_params(**overrides)
    { household_id: @household.id, custom_name: "Clean gutters", category: "maintenance",
      mental_load: "1", execution_load: "0", time_required: "30", frequency: "annually",
      anchor_on: "2026-11-30", assignee_keys: [ "", "user:#{users(:alice).id}", "user:#{users(:bob).id}" ] }.merge(overrides)
  end

  test "create saves a custom recurring chore (C5)" do
    assert_difference "Chore.count", 1 do
      post chores_path, params: { chore: custom_params }
    end
    chore = Chore.last
    assert_equal "Clean gutters", chore.custom_name
    assert_equal "maintenance", chore.category
    assert_nil chore.task_id
    assert chore.annually?
    assert_equal Date.new(2026, 11, 30), chore.anchor_on
    assert_equal @user, chore.created_by
    assert_equal [ "user:#{users(:alice).id}", "user:#{users(:bob).id}" ], chore.assignee_keys
    assert_redirected_to household_path(@household)
  end

  test "create goes back to the split or the catalogue it was opened from" do
    post chores_path, params: { chore: custom_params, return_to: "split" }
    assert_redirected_to household_split_path(@household, mode: "now")
    post chores_path, params: { chore: custom_params(custom_name: "Autre"), return_to: "catalogue" }
    assert_redirected_to household_chores_setup_path(@household)
  end

  test "C6: a missing name, load and duration are each told on their field" do
    assert_no_difference "Chore.count" do
      post chores_path, params: { chore: custom_params(custom_name: "", mental_load: "0", time_required: "0") }
    end
    assert_response :unprocessable_entity
    assert_select ".alert-box", 0
    assert_select ".field-error", /Donnez un nom à la tâche/
    assert_select ".field-error", /Cochez au moins une charge : mentale, exécution, ou les deux/
    assert_select ".field-error", /Indiquez une durée d'au moins 1 minute/
  end

  test "a custom chore needs someone assigned" do
    assert_no_difference "Chore.count" do
      post chores_path, params: { chore: custom_params(assignee_keys: [ "" ]) }
    end
    assert_select ".field-error", /Assignez la tâche à au moins une personne/
  end

  test "an assignee from another household is refused" do
    assert_no_difference "Chore.count" do
      post chores_path, params: { chore: custom_params(assignee_keys: [ "user:#{users(:carol).id}" ]) }
    end
    assert_response :unprocessable_entity
  end

  test "create ignores a task_id: catalogue chores come from the task list" do
    post chores_path, params: { chore: custom_params(task_id: tasks(:cook_meal).id) }
    assert_nil Chore.last.task_id
  end

  test "a chore added while the week's split is validated is logged outside the split (D14)" do
    plan = WeekPlan.propose!(household: @household, by: @user)
    plan.approve!(by: users(:bob))

    post chores_path, params: { chore: custom_params }

    assert_equal I18n.t("chores.flash.created_outside_split"), flash[:notice]
    assert_not plan.reload.includes_chore?(Chore.last)
  end

  # --- edit ---

  test "edit renders form for a chore in the user's household" do
    get edit_chore_path(chores(:smith_cooking))
    assert_response :success
  end

  test "edit redirects when chore belongs to a different household the user is not in" do
    # jones_cooking belongs to jones_home but alice IS in jones_home per fixtures
    # Use smith_custom which belongs to smith_home where alice IS — need a chore not in alice's household
    stranger = Household.create!(name: "Stranger")
    stranger_chore = insert_chore!(stranger, task: tasks(:cook_meal), status: :pending)

    get edit_chore_path(stranger_chore)
    assert_redirected_to chores_path
  ensure
    stranger_chore&.destroy
    stranger&.destroy
  end

  # --- update: custom chore allows name edit ---

  test "update allows editing custom_name on a custom chore" do
    chore = chores(:smith_custom)
    patch chore_path(chore), params: {
      chore: { custom_name: "Replace boiler", time_required: 120 }
    }
    assert_redirected_to household_path(@household)
    assert_equal "Replace boiler", chore.reload.custom_name
    assert_equal 120, chore.reload.time_required
  end

  # --- destroy ---

  test "destroy removes a custom chore, whoever created it (D14)" do
    chore = chores(:smith_custom)
    sign_in users(:bob) # created by Alice
    assert_difference "Chore.count", -1 do
      delete chore_path(chore)
    end
    assert_redirected_to household_chores_setup_path(@household)
  end

  test "C7: the delete screen says who created it and what stays" do
    chore = chores(:smith_custom)
    ChoreLog.create!(user: users(:alice), household: @household, chore: chore, mental_load: true,
                     execution_load: false, time_spent: 30, completed_at: Time.current)

    get delete_chore_path(chore)

    assert_response :success
    assert_select "h1", "Supprimer « Fix the boiler » ?"
    assert_text "Tâche perso créée par Alice"
    assert_text "Enregistrée 1 fois, par Alice (30 min)."
    assert_text "Cet enregistrement reste dans le journal"
    assert_no_match(/Seule la personne/, response.body)
  end

  test "destroy is blocked for catalogue chores" do
    chore = chores(:smith_cooking)
    assert_no_difference "Chore.count" do
      delete chore_path(chore)
    end
    assert_redirected_to household_chores_setup_path(@household)
  end

  test "create always uses the user's own household, whatever household_id is sent" do
    assert_difference -> { @household.chores.count }, 1 do
      assert_no_difference -> { households(:jones_home).chores.count } do
        post chores_path, params: { chore: {
          household_id: households(:jones_home).id, custom_name: "Sneaky", category: "other", time_required: "5",
          assignee_keys: [ "user:#{users(:alice).id}" ], mental_load: "1", execution_load: "0"
        } }
      end
    end
  end
end
