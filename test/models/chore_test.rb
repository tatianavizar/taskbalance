require "test_helper"

class ChoreTest < ActiveSupport::TestCase
  # --- catalogue_chore? / custom_chore? ---

  test "catalogue_chore? is true when task_id is set" do
    chore = chores(:smith_cooking)
    assert chore.catalogue_chore?
    assert_not chore.custom_chore?
  end

  test "custom_chore? is true when task_id is nil" do
    chore = chores(:smith_custom)
    assert chore.custom_chore?
    assert_not chore.catalogue_chore?
  end

  # --- effective_name ---

  test "effective_name returns task name for catalogue chore" do
    chore = chores(:smith_cooking)
    assert_equal chore.task.name, chore.effective_name
  end

  test "effective_name returns custom_name for custom chore" do
    chore = chores(:smith_custom)
    assert_equal "Fix the boiler", chore.effective_name
  end

  # --- effective_category ---

  test "effective_category returns task category for catalogue chore" do
    chore = chores(:smith_cooking)
    assert_equal "cooking", chore.effective_category
  end

  test "effective_category returns chore category for custom chore" do
    chore = chores(:smith_custom)
    assert_equal "maintenance", chore.effective_category
  end

  # --- effective_time_required ---

  test "effective_time_required falls back to task default when chore has none" do
    chore = chores(:smith_cooking)
    chore.time_required = nil
    assert_equal tasks(:cook_meal).time_required, chore.effective_time_required
  end

  test "effective_time_required uses chore override when set" do
    chore = chores(:smith_cooking)
    chore.time_required = 120
    assert_equal 120, chore.effective_time_required
  end

  test "effective_time_required returns nil for custom chore with no time_required" do
    chore = chores(:smith_custom)
    chore.time_required = nil
    assert_nil chore.effective_time_required
  end

  # --- validation: task_or_custom_name_present ---

  test "is invalid without task_id or custom_name" do
    chore = Chore.new(household: households(:smith_home))
    assert_not chore.valid?
    assert_includes chore.errors[:base].join, "Enter a chore name"
  end

  test "is valid with task_id and no custom_name" do
    chore = Chore.new(household: households(:smith_home), task: tasks(:cook_meal))
    assert chore.valid?, chore.errors.full_messages.inspect
  end

  test "is valid with custom_name and no task_id" do
    chore = Chore.new(household: households(:smith_home), custom_name: "Fix leaky tap", category: "maintenance")
    assert chore.valid?, chore.errors.full_messages.inspect
  end

  # --- validation: at_least_one_load_dimension ---

  test "is invalid when assigned but neither load dimension is set" do
    chore = Chore.new(
      household: households(:smith_home),
      task: tasks(:cook_meal),
      assigned_to: users(:alice),
      mental_load: false,
      execution_load: false
    )
    assert_not chore.valid?
    assert_includes chore.errors[:base].join, "At least one load dimension"
  end

  test "is valid when assigned with mental_load set" do
    chore = Chore.new(
      household: households(:smith_home),
      task: tasks(:cook_meal),
      assigned_to: users(:alice),
      mental_load: true,
      execution_load: false
    )
    assert chore.valid?, chore.errors.full_messages.inspect
  end
end
