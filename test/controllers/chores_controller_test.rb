require "test_helper"

class ChoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
    @household = households(:smith_home)
  end

  # --- new ---

  test "new redirects to households when household_id is missing" do
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

  test "create saves a custom chore with name and category" do
    assert_difference "Chore.count", 1 do
      post chores_path, params: {
        chore: {
          household_id: @household.id,
          custom_name: "Clean gutters",
          category: "maintenance"
        }
      }
    end
    chore = Chore.last
    assert_equal "Clean gutters", chore.custom_name
    assert_equal "maintenance", chore.category
    assert_nil chore.task_id
    assert_redirected_to household_path(@household)
  end

  test "create re-renders new when custom chore has no name" do
    assert_no_difference "Chore.count" do
      post chores_path, params: {
        chore: { household_id: @household.id, category: "maintenance" }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- create: catalogue chore ---

  test "create saves a catalogue chore with task_id" do
    task = tasks(:cook_meal)
    assert_difference "Chore.count", 1 do
      post chores_path, params: {
        chore: { household_id: @household.id, task_id: task.id }
      }
    end
    assert_equal task.id, Chore.last.task_id
    assert_redirected_to household_path(@household)
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
    stranger_chore = Chore.create!(household: stranger, task: tasks(:cook_meal), status: :pending)

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

  test "destroy removes a custom chore" do
    chore = chores(:smith_custom)
    assert_difference "Chore.count", -1 do
      delete chore_path(chore)
    end
    assert_redirected_to household_path(@household)
  end

  test "destroy is blocked for catalogue chores" do
    chore = chores(:smith_cooking)
    assert_no_difference "Chore.count" do
      delete chore_path(chore)
    end
    assert_redirected_to household_path(@household)
  end
end
