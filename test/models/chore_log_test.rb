require "test_helper"

class ChoreLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @household = households(:smith_home)
    @chore = chores(:smith_cooking)
  end

  def build_log(attrs = {})
    ChoreLog.new({
      chore: @chore,
      user: @user,
      mental_load: true,
      execution_load: false,
      time_spent: 30,
      completed_at: Time.current
    }.merge(attrs))
  end

  # --- snapshotting ---

  test "snapshots the chore name, category and household on create" do
    log = build_log
    assert log.save, log.errors.full_messages.to_sentence

    assert_equal @chore.effective_name, log.chore_name
    assert_equal @chore.effective_category, log.category
    assert_equal @household.id, log.household_id
  end

  test "snapshots a custom chore's own name and category" do
    custom = chores(:smith_custom)
    log = build_log(chore: custom)
    assert log.save, log.errors.full_messages.to_sentence

    assert_equal "Fix the boiler", log.chore_name
    assert_equal "maintenance", log.category
  end

  test "requires a chore name" do
    log = build_log(chore: nil)
    assert_not log.save
    assert_includes log.errors.attribute_names, :chore_name
  end

  # --- the data-ownership rule ---

  test "survives its chore being destroyed, keeping the snapshot" do
    log = build_log
    log.save!

    @chore.destroy

    log.reload
    assert_nil log.chore_id
    assert_equal "Cook a meal", log.chore_name
    assert_equal @user.id, log.user_id
    assert log.detached?
  end

  test "survives its whole household being destroyed" do
    log = build_log
    log.save!

    @household.destroy

    assert ChoreLog.exists?(log.id), "the log must outlive the household"
    log.reload
    assert_nil log.chore_id
    assert_nil log.household_id
    assert_equal @user.id, log.user_id
    assert_equal 30, log.time_spent
  end

  test "a user keeps every log after leaving and losing the household" do
    log = build_log
    log.save!
    other = build_log(chore: chores(:smith_laundry), time_spent: 15)
    other.save!

    @household.destroy

    kept = ChoreLog.where(user_id: @user.id)
    assert_equal 2, kept.count
    assert_equal ["Cook a meal", "Do laundry"], kept.order(:chore_name).pluck(:chore_name)
  end

  # --- attribution ---

  test "accepts any member of the chore's household as the doer" do
    log = build_log(user: users(:bob))
    assert log.save, log.errors.full_messages.to_sentence
  end

  test "rejects a doer who is not in the household" do
    outsider = User.create!(email: "outsider-model@test.com", first_name: "Outsider", password: "password123")
    log = build_log(user: outsider)

    assert_not log.save
    assert_includes log.errors[:user_id].join, "ne fait pas partie de ce foyer"
  ensure
    outsider&.destroy
  end

  test "the membership check does not block updating a detached log" do
    log = build_log
    log.save!
    @household.destroy
    log.reload

    assert_nil log.household_id
    assert log.update(time_spent: 99), log.errors.full_messages.to_sentence
  end

  # --- validations still hold ---

  test "requires at least one load dimension" do
    log = build_log(mental_load: false, execution_load: false)
    assert_not log.save
  end

  test "requires a positive time_spent" do
    assert_not build_log(time_spent: 0).save
  end
end
