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
      assert_equal 0, @household.chores.where.not(task_id: nil).count
    end

    test "update adds newly selected catalogue tasks" do
      @household.chores.where.not(task_id: nil).destroy_all
      task = tasks(:cook_meal)

      assert_difference "@household.chores.count", 1 do
        patch household_chores_setup_path(@household), params: { task_ids: [task.id] }
      end
    end

    test "update is scoped to households the user belongs to" do
      stranger = Household.create!(name: "Stranger Home")
      stranger.chores.create!(task: tasks(:cook_meal), status: :pending)

      patch household_chores_setup_path(stranger), params: { task_ids: [] }

      assert_response :not_found
      assert_equal 1, stranger.chores.count
    ensure
      stranger&.destroy
    end

    test "update ignores blank and unknown task ids" do
      assert_no_difference "Chore.count" do
        patch household_chores_setup_path(@household), params: {
          task_ids: ["", "0", "999999999"] + @household.chores.where.not(task_id: nil).pluck(:task_id).map(&:to_s)
        }
      end

      assert_redirected_to household_path(@household)
    end
  end
end
