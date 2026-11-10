require "test_helper"

# F4 (account), F7 (no household), B1/B2 (household creation).
class AccountScreensTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:alice)
    @alice.update!(password: "password123")
  end

  def sign_in_with_password
    post user_session_path, params: { user: { email: @alice.email, password: "password123" } }
  end

  # --- F4 ---------------------------------------------------------------

  test "the account screen lists the name, the email and the password, and logs out" do
    sign_in @alice
    get account_path

    assert_response :success
    assert_select "h1", "Mon compte"
    assert_select "a[href=?]", edit_first_name_path, text: /Alice/
    assert_select "a[href=?]", edit_email_path, text: /alice@test.com/
    assert_select "a[href=?]", edit_password_path
    assert_select "a[href=?]", intro_path(1), text: /Revoir l'introduction/
    assert_select "form[action=?] button", destroy_user_session_path, text: "Se déconnecter"
  end

  test "the account screen needs a session" do
    get account_path
    assert_redirected_to new_user_session_path
  end

  test "logging out ends the session and goes back to the welcome screen" do
    sign_in_with_password
    delete destroy_user_session_path
    assert_redirected_to root_path
    get account_path
    assert_redirected_to new_user_session_path
  end

  test "Devise's edit screen now sends to the account screen" do
    sign_in @alice
    get edit_user_registration_path
    assert_redirected_to account_path
  end

  test "the first name changes without a password and the monogram follows" do
    sign_in @alice
    patch edit_first_name_path, params: { user: { first_name: "Zoé" } }

    assert_redirected_to account_path
    assert_equal "Zoé", @alice.reload.first_name
    assert_equal "Z", @alice.household_membership.monogram
    follow_redirect!
    assert_select "[role=status]", "Prénom mis à jour."
  end

  test "a blank first name is refused with the message under the field" do
    sign_in @alice
    patch edit_first_name_path, params: { user: { first_name: " " } }

    assert_response :unprocessable_entity
    assert_select "input[aria-invalid=true]"
    assert_field_error "Indiquez votre prénom."
    assert_equal "Alice", @alice.reload.first_name
  end

  test "the email change asks for the current password and goes through confirmation" do
    sign_in @alice
    patch edit_email_path, params: { user: { email: "new@test.com", current_password: "wrong" } }
    assert_response :unprocessable_entity
    assert_field_error "Ce n'est pas votre mot de passe actuel."
    assert_equal "alice@test.com", @alice.reload.email

    assert_emails 1 do
      patch edit_email_path, params: { user: { email: "new@test.com", current_password: "password123" } }
    end
    assert_redirected_to pending_user_confirmation_path
    assert_equal "alice@test.com", @alice.reload.email # reconfirmable: the old one stays until confirmed
    assert_equal "new@test.com", @alice.unconfirmed_email
  end

  test "the password change needs the current password and a matching confirmation" do
    sign_in @alice

    patch edit_password_path, params: { user: { current_password: "wrong", password: "newpassword1", password_confirmation: "newpassword1" } }
    assert_response :unprocessable_entity
    assert_field_error "Ce n'est pas votre mot de passe actuel."

    patch edit_password_path, params: { user: { current_password: "password123", password: "newpassword1", password_confirmation: "other" } }
    assert_response :unprocessable_entity
    assert_field_error "Les deux mots de passe sont différents."

    patch edit_password_path, params: { user: { current_password: "password123", password: "", password_confirmation: "" } }
    assert_response :unprocessable_entity
    assert_field_error "Choisissez un mot de passe."

    patch edit_password_path, params: { user: { current_password: "password123", password: "abc", password_confirmation: "abc" } }
    assert_response :unprocessable_entity
    assert_field_error "Trop court : 6 caractères minimum."
    assert @alice.reload.valid_password?("password123")
  end

  test "changing the password keeps this session and ends the others" do
    sign_in_with_password
    old_cookie = cookies["remember_user_token"]
    assert old_cookie.present?

    patch edit_password_path, params: { user: { current_password: "password123", password: "newpassword1", password_confirmation: "newpassword1" } }
    assert_redirected_to account_path
    assert @alice.reload.valid_password?("newpassword1")
    assert_equal "Mot de passe modifié. Les autres appareils sont déconnectés.", flash[:notice]

    # this session is renewed for a week with the new password
    new_cookie = cookies["remember_user_token"]
    assert new_cookie.present?
    assert_not_equal old_cookie, new_cookie
    cookies.delete("_task_balance_session")
    get account_path
    assert_response :success

    # another device still holding the old remember cookie is signed out
    reset!
    cookies["remember_user_token"] = old_cookie
    get account_path
    assert_redirected_to new_user_session_path
  end

  # --- F7 ---------------------------------------------------------------

  test "an account without a household sees the no-household screen" do
    dana = users(:dana)
    sign_in dana
    get dashboard_path

    assert_response :success
    assert_select "h1", "Vous n'êtes dans aucun foyer"
    assert_select "nav.tab-bar", 0
    assert_select "a[href=?]", new_household_path, text: "Créer un foyer"
    assert_select "a[href=?]", account_path, text: "Mon compte"
    assert_select "a[aria-label=?]", "Mon compte"
    assert_match "Votre journal vous suit", response.body
  end

  # --- B1 / B2 ----------------------------------------------------------

  test "the household creation screen shows the set-up steps and the name field" do
    sign_in users(:dana)
    get new_household_path

    assert_response :success
    assert_select "h1", "Comment s'appelle votre foyer ?"
    assert_select "[role=group][aria-label=?]", "Étape 1 sur 4"
    assert_select "[aria-current=step]", "Foyer"
    assert_select ".field-hint", "60 caractères maximum."
    assert_select "input[type=submit][value=Continuer]"
  end

  test "an empty name shows the message under the field and no summary box" do
    sign_in users(:dana)
    post households_path, params: { household: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "input[aria-invalid=true]"
    assert_field_error "Donnez un nom au foyer pour continuer. Par exemple : Chez Virginie et Karim."
    assert_select ".alert-box", 0
  end
end
