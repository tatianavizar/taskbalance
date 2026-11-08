require "test_helper"

# Chaque écran converti au form builder et aux composants doit se rendre sans
# erreur, en français, avec un seul <h1> et un titre de page.
class ViewsRenderTest < ActionDispatch::IntegrationTest
  setup { @household = households(:smith_home) }

  test "public screens render" do
    [ root_path, new_user_session_path, new_user_registration_path, new_user_password_path,
      edit_user_password_path(reset_password_token: "jeton") ].each do |path|
      get path
      assert_response :success, path
      assert_select "h1", 1, path
      assert_select "html[lang=fr]"
      assert_select "nav.tab-bar", 0, path
    end
  end

  test "signed-in screens render" do
    sign_in users(:alice)
    chore = chores(:smith_cooking)

    [ dashboard_path, report_path, tasks_path, chores_path, household_path(@household),
      edit_household_path(@household), new_household_household_member_path(@household),
      new_chore_path(household_id: @household.id), edit_chore_path(chore), edit_chore_path(chores(:smith_custom)),
      new_chore_completion_path(chore), household_chores_setup_path(@household),
      household_liking_session_path(@household), edit_user_registration_path ].each do |path|
      get path
      assert_response :success, path
      assert_select "h1", 1, path
      assert_select "title", /50\/50/, path
    end
  end

  test "a form with errors shows the dark summary and the inline error" do
    sign_in users(:alice)
    post household_household_members_path(@household), params: { household_member: { email: "pas-un-email" } }

    assert_response :unprocessable_entity
    assert_select ".alert-box[role=alert]", /champ à corriger/
    assert_select "input[aria-invalid=true]"
    assert_select ".field-error"
  end

  test "flash messages are announced with role status" do
    sign_in users(:dana) # no household yet: one household per account
    post households_path, params: { household: { name: "Chez nous" } }
    follow_redirect!

    assert_select "[role=status]", "Foyer créé."
  end
end
