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

  test "the styleguide shows the progress components of the intro and the set-up" do
    get styleguide_path

    assert_response :success
    assert_select "#sg-progress [role=img][aria-label=?]", "Écran 1 sur 3"
    assert_select "#sg-progress [role=group][aria-label=?]", "Étape 3 sur 4"
    assert_select "#sg-countdown [data-controller=countdown]"
  end

  test "signed-in screens render" do
    sign_in users(:alice)
    chore = chores(:smith_cooking)

    [ dashboard_path, report_path, report_history_path, levels_path, member_pauses_path, new_member_pause_path,
      absence_inquiries_path, tasks_path, chores_path, household_path(@household),
      edit_household_path(@household), new_household_invitation_path(@household),
      new_chore_path(household_id: @household.id), edit_chore_path(chore), edit_chore_path(chores(:smith_custom)),
      new_chore_log_path(chore_id: chore.id), chore_path(chore), chore_logs_path, household_chores_setup_path(@household),
      household_preferences_path(@household), household_split_path(@household, mode: "now"), household_split_settings_path(@household), account_path, edit_first_name_path,
      edit_email_path, edit_password_path, pending_user_confirmation_path ].each do |path|
      get path
      assert_response :success, path
      assert_select "h1", 1, path
      assert_select "title", /50\/50/, path
    end
  end

  test "a form with errors shows the dark summary and the inline error" do
    sign_in users(:alice)
    post household_invitations_path(@household), params: { invitation: { first_name: "Karim", email: "pas-un-email" } }

    assert_response :unprocessable_entity
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
