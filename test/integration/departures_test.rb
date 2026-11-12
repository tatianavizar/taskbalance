require "test_helper"

# Lot 7 screens through HTTP: F1 (household), F2 (leave), F3 (delete the
# household), F5 (delete the account), F11 (no household after leaving).
class DeparturesTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @household = households(:smith_home)
    @alice = users(:alice) # manager
    @bob = users(:bob)
    [ @alice, @bob ].each { |user| user.update!(password: "password123") }
  end

  # ---- F1 -------------------------------------------------------------------

  test "F1 lists the members with their role; only the manager gets « Supprimer le foyer »" do
    sign_in @alice
    get household_path(@household)
    assert_response :success
    assert_text "Alice (vous)"
    assert_text "Gestionnaire · depuis le"
    assert_text "Membre · depuis le"
    assert_select "a[href=?]", new_household_departure_path(@household), text: /Quitter le foyer/
    assert_select "a[href=?]", delete_household_path(@household)

    sign_in @bob
    get household_path(@household)
    assert_select "a[href=?]", delete_household_path(@household), count: 0
    assert_text "Seule la personne qui gère le foyer, Alice, peut le supprimer."
  end

  # ---- F2 then F11 ----------------------------------------------------------

  test "F2 says what follows, leaving lands on F11 and keeps the logs" do
    chore = chores(:smith_custom)
    log = ChoreLog.create!(user: @alice, chore: chore, mental_load: true, execution_load: false, time_spent: 10, completed_at: Time.current)
    sign_in @alice

    get new_household_departure_path(@household)
    assert_response :success
    assert_select "h1", "Quitter Smith Home ?"
    assert_text "Votre journal vous suit"
    assert_text "passent à Bob"
    assert_text "Bob devient gestionnaire."
    assert_text "Pour revenir, il faudra une nouvelle invitation."

    post household_departure_path(@household)
    assert_redirected_to dashboard_path(departed: 1)
    follow_redirect!
    assert_text "Vous avez quitté « Smith Home »."
    assert_text "Pour rejoindre un autre foyer"

    assert_nil @alice.reload.household
    assert_nil log.reload.household_id
    assert_equal @alice.id, log.user_id
    assert @household.household_members.find_by!(user: @bob).manager?
    assert_equal [ @bob.id ], chore.reload.chore_assignees.map(&:user_id)
  end

  test "someone cannot leave a household that is not theirs" do
    sign_in users(:carol)
    post household_departure_path(@household)
    assert_response :not_found
    assert @alice.reload.household
  end

  test "happy path: leave, then join another household through an invitation" do
    carol = users(:carol)
    jones = households(:jones_home)
    invitation = Invitation.invite(household: jones, email: @alice.email, first_name: "Alice", inviter: carol)
    assert invitation.persisted?
    sign_in @alice

    get invitation_path(invitation.token)
    assert_text "Smith Home" # B9: leave it first

    post household_departure_path(@household)
    get invitation_path(invitation.token)
    assert_response :success
    post claim_invitation_path(invitation.token)
    post accept_invitation_path(invitation.token)
    assert_redirected_to household_path(jones)

    assert_equal jones, @alice.reload.household
    assert_not jones.household_members.find_by!(user: @alice).manager?
    assert_equal [ @bob ], @household.reload.users.to_a
  end

  # ---- F3 -------------------------------------------------------------------

  test "F3: a member who does not manage the household can neither see the form nor delete" do
    sign_in @bob
    get delete_household_path(@household)
    assert_redirected_to household_path(@household)

    delete household_path(@household), params: { household_deletion: { confirmation_name: "Smith Home" } }
    assert_redirected_to household_path(@household)
    assert Household.exists?(@household.id)
  end

  test "F3: a wrong name re-renders with an error and deletes nothing" do
    sign_in @alice
    get delete_household_path(@household)
    assert_response :success
    assert_text "Action définitive, pour Alice et pour Bob."
    assert_text "Bob recevra un email."

    delete household_path(@household), params: { household_deletion: { confirmation_name: "Smith" } }
    assert_response :unprocessable_entity
    assert_field_error "Ce n'est pas le nom du foyer. Saisissez-le exactement comme il s'affiche."
    assert Household.exists?(@household.id)
  end

  test "F3: the manager deletes it, nobody is emailed, Bob reads the notice once on his landing screen" do
    log = ChoreLog.create!(user: @bob, chore: chores(:smith_laundry), mental_load: false, execution_load: true, time_spent: 10, completed_at: Time.current)
    @bob.update_columns(confirmed_at: Time.current)
    sign_in @alice

    assert_no_enqueued_emails do
      delete household_path(@household), params: { household_deletion: { confirmation_name: "Smith Home" } }
    end
    assert_redirected_to dashboard_path(departed: 1)
    assert_not Household.exists?(@household.id)
    assert_nil @bob.reload.household
    assert_nil log.reload.household_id
    assert ChoreLog.exists?(log.id)

    sign_in @bob
    assert_equal 1, Notification.unread_count_for(@bob)
    get dashboard_path(departed: 1)
    assert_text "Alice a supprimé le foyer « Smith Home »."
    assert_text "Votre journal vous suit"
    assert_equal 0, Notification.unread_count_for(@bob)

    get dashboard_path
    assert_not_includes response.body, "Alice a supprimé le foyer"
  end

  # ---- F5 -------------------------------------------------------------------

  test "F5 asks for the password and a confirmation" do
    sign_in @alice
    get account_path
    assert_select "a[href=?]", delete_account_path

    get delete_account_path
    assert_response :success
    assert_text "Vous quittez d'abord « Smith Home »"
    assert_text "Bob devient gestionnaire."

    delete user_registration_path, params: { account_deletion: { current_password: "wrong", confirmed: "1" } }
    assert_response :unprocessable_entity
    assert_field_error "Mot de passe incorrect."

    delete user_registration_path, params: { account_deletion: { current_password: "password123", confirmed: "0" } }
    assert_response :unprocessable_entity
    assert_not @alice.reload.deleted?
  end

  test "F5 deletes the account, signs out, and the old credentials no longer work" do
    sign_in @alice
    delete user_registration_path, params: { account_deletion: { current_password: "password123", confirmed: "1" } }
    assert_redirected_to root_path

    @alice.reload
    assert @alice.deleted?
    assert_equal "Ancien membre", @alice.first_name
    get dashboard_path
    assert_redirected_to new_user_session_path

    post user_session_path, params: { user: { email: "alice@test.com", password: "password123" } }
    get dashboard_path
    assert_redirected_to new_user_session_path
    assert @household.household_members.find_by!(user: @bob).manager?
  end
end
