require "test_helper"

module Households
  class ChoresSetupControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:alice)
      sign_in @user
      @household = households(:smith_home)
      @custom_chore = chores(:smith_custom)
    end

    test "show renders the catalogue" do
      get household_chores_setup_path(@household)
      assert_response :success
    end

    test "update keeps custom chores when catalogue selection is unchanged" do
      task_ids = @household.chores.where.not(task_id: nil).pluck(:task_id)

      patch household_chores_setup_path(@household), params: { task_ids: task_ids }

      assert_redirected_to household_path(@household)
      assert Chore.exists?(@custom_chore.id), "custom chore must survive a catalogue save"
    end

    test "update keeps custom chores when every catalogue task is removed" do
      patch household_chores_setup_path(@household), params: { task_ids: [] }

      assert_redirected_to household_path(@household)
      assert Chore.exists?(@custom_chore.id), "custom chore must survive removing all catalogue tasks"
      assert_equal 0, @household.chores.catalogue.active.count
      assert @household.chores.catalogue.retired.exists?, "unticked catalogue chores are retired, not deleted"
    end

    test "update adds newly selected catalogue tasks" do
      @household.chores.where.not(task_id: nil).destroy_all
      task = tasks(:cook_meal)

      assert_difference "@household.chores.count", 1 do
        patch household_chores_setup_path(@household), params: { task_ids: [ task.id ] }
      end
    end

    test "update is scoped to households the user belongs to" do
      stranger = Household.create!(name: "Stranger Home")
      insert_chore!(stranger, task: tasks(:cook_meal), status: :pending)

      patch household_chores_setup_path(stranger), params: { task_ids: [] }

      assert_response :not_found
      assert_equal 1, stranger.chores.count
    ensure
      stranger&.destroy
    end

    test "M1: the household's tasks, with custom ones and their delete link" do
      get household_chores_setup_path(@household)

      assert_select "h1", "Tâches du foyer"
      assert_select "a[href=?][aria-label=?]", delete_chore_path(@custom_chore), "Supprimer Fix the boiler"
      assert_select "input[type=submit][value=?]", "Enregistrer les changements"
    end

    test "C2: unticking a task that was logged asks first, with who logged it" do
      laundry = chores(:smith_laundry)
      ChoreLog.create!(user: users(:bob), household: @household, chore: laundry, mental_load: false,
                       execution_load: true, time_spent: 10, completed_at: Time.current)

      patch household_chores_setup_path(@household), params: { task_ids: [ tasks(:cook_meal).id ] }

      assert_response :unprocessable_entity
      assert_select "h1", "Retirer « Do laundry » ?"
      assert_text "Le foyer l'a enregistrée 1 fois"
      assert_text "Bob 1 fois"
      assert laundry.reload.active?, "nothing is retired before the confirmation"

      patch household_chores_setup_path(@household), params: { task_ids: [ tasks(:cook_meal).id ], confirm_retire: "1" }

      assert_not laundry.reload.active?
      assert_equal 1, laundry.chore_logs.count, "its logs stay"
    end

    test "re-ticking a retired catalogue task brings the same chore back" do
      laundry = chores(:smith_laundry)
      @household.chores.where(task: tasks(:do_laundry)).update_all(active: false)

      assert_no_difference "Chore.count" do
        patch household_chores_setup_path(@household), params: { task_ids: [ tasks(:cook_meal).id, tasks(:do_laundry).id ] }
      end
      assert laundry.reload.active?
    end

    test "a new task is placed by the proposal, the others keep their assignees" do
      ChorePreference.create!(user: users(:bob), chore: chores(:smith_cooking), choice: "like")
      task_ids = @household.chores.catalogue.pluck(:task_id).uniq + [ tasks(:pay_bills).id ]

      patch household_chores_setup_path(@household), params: { task_ids: task_ids }

      bills = @household.chores.find_by!(task: tasks(:pay_bills))
      assert_equal 1, bills.assignee_keys.size
      assert_equal [ "user:#{users(:alice).id}" ], chores(:smith_cooking).reload.assignee_keys
    end

    test "update ignores blank and unknown task ids" do
      assert_no_difference "Chore.count" do
        patch household_chores_setup_path(@household), params: {
          task_ids: [ "", "0", "999999999" ] + @household.chores.where.not(task_id: nil).pluck(:task_id).map(&:to_s)
        }
      end

      assert_redirected_to household_path(@household)
    end
  end
end
