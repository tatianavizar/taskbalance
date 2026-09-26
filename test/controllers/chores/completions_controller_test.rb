require "test_helper"

module Chores
  class CompletionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:alice)
      sign_in @user
      @household = households(:smith_home)
      @chore = chores(:smith_cooking)
    end

    def valid_params(overrides = {})
      { chore_log: {
        mental_load: "1",
        execution_load: "0",
        time_spent: "45",
        user_id: @user.id
      }.merge(overrides) }
    end

    # --- new ---

    test "new renders the form" do
      get new_chore_completion_path(@chore)
      assert_response :success
    end

    test "new prefills the minutes from the chore's effective time" do
      get new_chore_completion_path(@chore)
      assert_match(/value="45"/, response.body)
    end

    test "new lists every household member as a possible doer" do
      get new_chore_completion_path(@chore)
      assert_match users(:bob).email, response.body
    end

    test "new is scoped to the user's own households" do
      stranger = Household.create!(name: "Stranger Home")
      other_chore = stranger.chores.create!(task: tasks(:cook_meal), status: :pending)

      get new_chore_completion_path(other_chore)

      assert_redirected_to chores_path
    ensure
      other_chore&.destroy
      stranger&.destroy
    end

    # --- create ---

    test "create records a log with the submitted loads, minutes and doer" do
      assert_difference "ChoreLog.count", 1 do
        post chore_completion_path(@chore), params: valid_params
      end

      log = ChoreLog.last
      assert_equal @user.id, log.user_id
      assert_equal @chore.id, log.chore_id
      assert_equal @household.id, log.household_id
      assert_equal 45, log.time_spent
      assert log.mental_load
      assert_not log.execution_load
      assert_equal "Cook a meal", log.chore_name
      assert_not_nil log.completed_at
    end

    test "create marks the chore completed and redirects with a notice" do
      post chore_completion_path(@chore), params: valid_params

      assert_redirected_to chores_path
      assert_equal "Logged: Cook a meal.", flash[:notice]
      assert @chore.reload.completed?
    end

    test "the confirmation is actually rendered on the next page" do
      post chore_completion_path(@chore), params: valid_params
      follow_redirect!

      assert_response :success
      assert_match "Logged: Cook a meal.", response.body
    end

    test "create can log on another member's behalf" do
      post chore_completion_path(@chore), params: valid_params(user_id: users(:bob).id)

      assert_equal users(:bob).id, ChoreLog.last.user_id
    end

    test "create rejects a doer from outside the household" do
      outsider = User.create!(email: "outsider@test.com", password: "password123")

      assert_no_difference "ChoreLog.count" do
        post chore_completion_path(@chore), params: valid_params(user_id: outsider.id)
      end

      assert_response :unprocessable_entity
      assert_not @chore.reload.completed?
    ensure
      outsider&.destroy
    end

    test "create rejects a submission with neither load dimension" do
      assert_no_difference "ChoreLog.count" do
        post chore_completion_path(@chore), params: valid_params(mental_load: "0", execution_load: "0")
      end

      assert_response :unprocessable_entity
      assert_not @chore.reload.completed?
    end

    test "create rejects a non-positive time spent" do
      assert_no_difference "ChoreLog.count" do
        post chore_completion_path(@chore), params: valid_params(time_spent: "0")
      end

      assert_response :unprocessable_entity
    end

    test "create ignores a client-supplied completed_at" do
      post chore_completion_path(@chore), params: valid_params(completed_at: 3.years.ago)

      assert_in_delta Time.current, ChoreLog.last.completed_at, 1.minute
    end

    test "create is scoped to the user's own households" do
      stranger = Household.create!(name: "Stranger Home")
      other_chore = stranger.chores.create!(task: tasks(:cook_meal), status: :pending)

      assert_no_difference "ChoreLog.count" do
        post chore_completion_path(other_chore), params: valid_params
      end

      assert_redirected_to chores_path
    ensure
      other_chore&.destroy
      stranger&.destroy
    end

    # --- recurrence ---

    test "completing a recurring chore spawns the next occurrence" do
      recurring_chore = chores(:smith_recurring)

      assert_difference "Chore.count", 1 do
        post chore_completion_path(recurring_chore), params: valid_params
      end

      spawned = Chore.where(recurring_chore: recurring_chores(:smith_weekly_laundry)).order(:id).last
      assert spawned.pending?
      assert_equal Date.today + 1.week, spawned.due_date
    end

    test "a spawn failure still leaves the log saved and the chore completed" do
      broken = chores(:smith_from_broken_template)

      assert_difference "ChoreLog.count", 1 do
        post chore_completion_path(broken), params: valid_params
      end

      assert_redirected_to chores_path
      assert broken.reload.completed?
    end

    test "completing a non-recurring chore spawns nothing" do
      assert_no_difference "Chore.count" do
        post chore_completion_path(@chore), params: valid_params
      end
    end

    # --- auth ---

    test "the completion form requires authentication" do
      sign_out @user
      get new_chore_completion_path(@chore)
      assert_redirected_to new_user_session_path
    end
  end
end
