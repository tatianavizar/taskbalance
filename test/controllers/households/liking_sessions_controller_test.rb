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
  end
end
