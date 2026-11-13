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

  # --- validations ---

  def valid_custom(**attrs)
    Chore.new({ household: households(:smith_home), custom_name: "Renouveler l'assurance", category: "admin",
                mental_load: true, time_required: 30, assignee_user_ids: [ users(:alice).id ] }.merge(attrs))
  end

  test "a custom chore without a name says so on the name field" do
    chore = valid_custom(custom_name: "  ")
    assert_not chore.valid?
    assert_includes chore.errors[:custom_name].join, "Donnez un nom à la tâche"
  end

  test "a catalogue chore takes its task's loads and needs no name" do
    chore = Chore.new(household: households(:smith_home), task: tasks(:cook_meal), assignee_user_ids: [ users(:alice).id ])
    assert chore.valid?, chore.errors.full_messages.inspect
    assert chore.execution_load
    assert_not chore.mental_load
  end

  test "a valid custom chore" do
    assert valid_custom.valid?, valid_custom.errors.full_messages.inspect
  end

  test "every chore needs at least one load (C6)" do
    chore = valid_custom(mental_load: false, execution_load: false)
    assert_not chore.valid?
    assert_includes chore.errors[:loads].join, "Cochez au moins une charge : mentale, exécution, ou les deux."
  end

  test "a custom chore needs a duration of at least 1 minute (C6)" do
    [ nil, 0, -5 ].each do |minutes|
      chore = valid_custom(time_required: minutes)
      assert_not chore.valid?, minutes.inspect
      assert_includes chore.errors[:time_required], "Indiquez une durée d'au moins 1 minute."
    end
  end

  test "a chore needs at least one assignee" do
    chore = valid_custom(assignee_user_ids: [])
    assert_not chore.valid?
    assert_includes chore.errors[:assignees], "Assignez la tâche à au moins une personne."
  end

  test "an assignee must be a member of the household" do
    chore = valid_custom(assignee_user_ids: [ users(:carol).id ])
    assert_not chore.valid?
    assert_includes chore.errors[:assignees], "Une personne choisie ne fait pas partie du foyer."
  end

  test "a forged assignee key is refused" do
    chore = valid_custom
    chore.assignee_keys = [ "user:#{users(:alice).id}", "admin:1" ]
    assert_not chore.valid?
    assert chore.errors[:assignees].any?
  end

  test "a chore shared by every member keeps one row per member (D6)" do
    chore = valid_custom(assignee_user_ids: [ users(:alice).id, users(:bob).id ])
    chore.save!
    assert_equal 2, chore.chore_assignees.count
    assert_equal [ users(:alice), users(:bob) ].sort_by(&:id), chore.assigned_users.order(:id).to_a
  end

  test "replacing the assignees removes the old rows" do
    chore = chores(:smith_cooking)
    chore.update!(assignee_user_ids: [ users(:bob).id ])
    assert_equal [ "user:#{users(:bob).id}" ], chore.reload.assignee_keys
  end

  test "someone invited but not yet in can be assigned (D15)" do
    invitation = households(:smith_home).invitations.create!(email: "karim@example.com")
    chore = valid_custom
    chore.assignee_keys = [ "invitation:#{invitation.id}" ]
    assert chore.save, chore.errors.full_messages.inspect
    assert_equal invitation, chore.chore_assignees.first.invitation
  end

  test "times per period only repeats daily and weekly chores" do
    assert valid_custom(frequency: :weekly, times_per_period: 3).valid?
    chore = valid_custom(frequency: :monthly, times_per_period: 2)
    assert_not chore.valid?
    assert chore.errors[:times_per_period].any?
  end

  test "monthly, yearly and one-off chores get today as due date by default" do
    chore = valid_custom(frequency: :annually)
    chore.valid?
    assert_equal households(:smith_home).today, chore.anchor_on
    assert_nil valid_custom(frequency: :weekly).tap(&:valid?).anchor_on
  end

  # --- occurrences in a week (the planned weight) ---

  test "a daily chore counts 7 times a week, a weekly one its times per period" do
    week = Week.containing(Date.new(2026, 11, 11), "Europe/Paris")
    assert_equal 7, valid_custom(frequency: :daily).occurrences_in(week)
    assert_equal 14, valid_custom(frequency: :daily, times_per_period: 2).occurrences_in(week)
    assert_equal 3, valid_custom(frequency: :weekly, times_per_period: 3).occurrences_in(week)
  end

  test "a monthly chore counts in the week of its day of the month only" do
    chore = valid_custom(frequency: :monthly, anchor_on: Date.new(2026, 10, 14))
    assert_equal 1, chore.occurrences_in(Week.containing(Date.new(2026, 11, 14), "Europe/Paris"))
    assert_equal 0, chore.occurrences_in(Week.containing(Date.new(2026, 11, 21), "Europe/Paris"))
    # Not before its first due date.
    assert_equal 0, chore.occurrences_in(Week.containing(Date.new(2026, 9, 14), "Europe/Paris"))
  end

  test "a monthly chore due on the 31st falls on the last day of a shorter month" do
    chore = valid_custom(frequency: :monthly, anchor_on: Date.new(2026, 10, 31))
    assert_equal 1, chore.occurrences_in(Week.containing(Date.new(2026, 11, 30), "Europe/Paris"))
  end

  test "a yearly chore counts once a year, a one-off chore once" do
    yearly = valid_custom(frequency: :annually, anchor_on: Date.new(2025, 11, 30))
    assert_equal 1, yearly.occurrences_in(Week.containing(Date.new(2026, 11, 30), "Europe/Paris"))
    assert_equal 0, yearly.occurrences_in(Week.containing(Date.new(2026, 11, 23), "Europe/Paris"))

    once = valid_custom(frequency: :once, anchor_on: Date.new(2026, 11, 30))
    assert_equal 1, once.occurrences_in(Week.containing(Date.new(2026, 12, 1), "Europe/Paris"))
    assert_equal 0, once.occurrences_in(Week.containing(Date.new(2027, 11, 30), "Europe/Paris"))
  end

  # --- retire, delete ---

  test "destroying a chore keeps its logs, detached, and drops its assignees and preferences" do
    chore = chores(:smith_custom)
    log = ChoreLog.create!(user: users(:alice), household: chore.household, chore: chore, mental_load: true,
                           execution_load: false, time_spent: 30, completed_at: Time.current)
    ChorePreference.create!(user: users(:alice), chore: chore, choice: "like")

    chore.destroy!

    assert_nil log.reload.chore_id
    assert_equal "Fix the boiler", log.chore_name
    assert_equal 0, ChoreAssignee.where(chore_id: chore.id).count
    assert_equal 0, ChorePreference.where(chore_id: chore.id).count
  end

  test "log_counts_by_member counts the household's logs per first name" do
    chore = chores(:smith_cooking)
    2.times { ChoreLog.create!(user: users(:bob), household: chore.household, chore: chore, mental_load: false, execution_load: true, time_spent: 5, completed_at: Time.current) }
    ChoreLog.create!(user: users(:alice), household: chore.household, chore: chore, mental_load: false, execution_load: true, time_spent: 5, completed_at: Time.current)

    assert_equal({ "Bob" => 2, "Alice" => 1 }, chore.log_counts_by_member)
  end
end
