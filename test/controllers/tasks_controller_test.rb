require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get tasks_path
    assert_redirected_to new_user_session_path
  end

  test "index renders the catalogue grouped by category" do
    sign_in users(:alice)

    get tasks_path

    assert_response :success
    assert_match tasks(:cook_meal).name, response.body
    assert_match I18n.t("tasks.categories.cooking"), response.body
  end
end
