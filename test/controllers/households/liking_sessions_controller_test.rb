require "test_helper"

module Households
  class LikingSessionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:alice)
      sign_in @user
      @household = households(:smith_home)
    end

    test "show renders when the household has a custom chore with no task" do
      assert @household.chores.where(task_id: nil).exists?, "fixture must include a custom chore"

      get household_liking_session_path(@household)

      assert_response :success
    end

    test "show lists catalogue tasks and not the custom chore" do
      get household_liking_session_path(@household)

      assert_response :success
      assert_match tasks(:cook_meal).name, response.body
      assert_no_match(/Fix the boiler/, response.body)
    end

    test "update saves preferences for the current user" do
      task = tasks(:cook_meal)

      patch household_liking_session_path(@household), params: {
        preferences: { task.id.to_s => "true" }
      }

      assert_redirected_to household_path(@household)
      assert LikedTask.find_by(user: @user, task: task).liked
    end

    test "update refuses a task that is not a chore of the household and writes nothing" do
      foreign = Task.create!(name: "Not in this household", time_required: 5, priority: 1)
      own = tasks(:cook_meal)

      assert_no_difference "LikedTask.count" do
        patch household_liking_session_path(@household), params: {
          preferences: { own.id.to_s => "true", foreign.id.to_s => "true" }
        }
      end

      assert_response :unprocessable_entity
    end

    test "update refuses a task that only another household has" do
      assert households(:jones_home).chores.where(task: tasks(:cook_meal)).exists?
      only_jones = Task.create!(name: "Jones only", time_required: 5, priority: 1)
      households(:jones_home).chores.create!(task: only_jones, status: :pending)

      assert_no_difference "LikedTask.count" do
        patch household_liking_session_path(@household), params: { preferences: { only_jones.id.to_s => "false" } }
      end
      assert_response :unprocessable_entity
    end
  end
end
