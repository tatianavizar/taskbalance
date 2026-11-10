require "test_helper"

# A2 to A10: the sign-up, sign-in, password reset and email confirmation screens.
class AuthScreensTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def sign_up(**overrides)
    post user_registration_path, params: { user: {
      email: "nina@test.com", first_name: "Nina", password: "password123", password_confirmation: "password123"
    }.merge(overrides) }
  end

  # --- A2 / A3 ----------------------------------------------------------

  test "the sign-up screen explains who sees the first name and what happens to the email" do
    get new_user_registration_path

    assert_select "h1", "Créer un compte"
    assert_select ".field-hint", /Visible par les membres de votre foyer/
    assert_select ".field-hint", /Un lien de confirmation part à cette adresse/
    assert_select ".field-hint", "6 caractères minimum."
    assert_match "Vos enregistrements vous appartiennent", response.body
    assert_select "input[type=hidden][name='user[time_zone]']"
  end

  test "a too short password is reported under its field, with the count" do
    sign_up(password: "abc", password_confirmation: "abc")

    assert_response :unprocessable_entity
    assert_select ".alert-box", /1 champ à corriger/
    assert_select "input[aria-invalid=true]", 1
    assert_field_error "Trop court : 6 caractères minimum."
  end

  test "the browser time zone is kept when valid and ignored when unknown" do
    sign_up(time_zone: "America/Montreal")
    assert_equal "America/Montreal", User.find_by!(email: "nina@test.com").time_zone

    reset!
    sign_up(email: "luc@test.com", time_zone: "Mars/Olympus")
    assert_equal "Europe/Paris", User.find_by!(email: "luc@test.com").time_zone
  end

  # --- A10 --------------------------------------------------------------

  test "sign-up lands on the confirm-your-email screen, which never blocks" do
    sign_up
    assert_redirected_to pending_user_confirmation_path
    follow_redirect!

    assert_select "h1", "Confirmez votre email"
    assert_select "b", "nina@test.com"
    assert_match "24 heures", response.body
    assert_select "a[href=?]", new_household_path, text: "J'ai confirmé, continuer"
    assert_select "a[href=?]", edit_email_path, text: "Changer d'adresse"
    # the button is disabled for a minute: the mail has just been sent
    assert_select "[data-controller=countdown] button[disabled]"
    assert_select "[data-countdown-seconds-value]" do |nodes|
      assert_includes 55..60, nodes.first["data-countdown-seconds-value"].to_i
    end
  end

  test "an invited sign-up skips the confirmation screen" do
    invitation = Invitation.create!(email: "guest@test.com", household: households(:smith_home))
    get new_user_registration_path(invitation_token: invitation.token)
    sign_up(email: "guest@test.com")

    assert_redirected_to dashboard_path
  end

  test "the confirm screen needs a session and, once confirmed, says so" do
    get pending_user_confirmation_path
    assert_redirected_to new_user_session_path

    sign_in users(:alice)
    get pending_user_confirmation_path
    assert_select "h1", "Confirmez votre email"
    assert_match "Votre adresse est confirmée.", response.body
    assert_select "[data-controller=countdown]", 0
  end

  test "the resend button works again after the delay, and the resend stays rate limited" do
    sign_up
    travel 61.seconds do
      get pending_user_confirmation_path
      assert_select "[data-controller=countdown] button:not([disabled])"
      assert_select "[data-countdown-seconds-value=?]", "0"
    end

    assert_emails 1 do
      post user_confirmation_path, params: { user: { email: "nina@test.com" } }
    end
    assert_redirected_to pending_user_confirmation_path
  end

  # --- A4 / A5 ----------------------------------------------------------

  test "the sign-in screen has no remember box: the session lasts a week anyway" do
    get new_user_session_path

    assert_select "h1", "Se connecter"
    assert_select "input[type=checkbox]", 0
    assert_match "La session reste ouverte une semaine.", response.body
    assert_select "a[href=?]", new_user_password_path
    assert_select ".alert-box", 0
  end

  test "a failed sign-in shows the ink alert once, with the same text for any cause" do
    users(:alice).update!(password: "password123")
    post user_session_path, params: { user: { email: "alice@test.com", password: "wrong" } }
    known = response.body[/<div class="alert-box".*?<\/div>/m]
    assert_response :unprocessable_entity
    assert_select ".alert-box[role=alert]", 1
    assert_select ".alert-box", /Email ou mot de passe incorrect\./
    assert_select ".alert-box", /recevez un lien pour choisir un nouveau mot de passe/
    assert_select "input[aria-invalid=true]", 2
    assert_select "a[href=?]", new_user_password_path, text: "Recevoir un lien de réinitialisation"
    assert_match "volontaire", response.body

    reset!
    post user_session_path, params: { user: { email: "nobody@test.com", password: "wrong" } }
    assert_equal known, response.body[/<div class="alert-box".*?<\/div>/m]
  end

  test "being sent to sign in after a protected page shows the generic message, not the failure screen" do
    get dashboard_path
    follow_redirect!

    assert_select ".alert-box", /Connectez-vous ou créez un compte/
    assert_select "input[aria-invalid=true]", 0
  end

  # --- A6 / A7 ----------------------------------------------------------

  test "the forgot-password screen states the validity of the link" do
    get new_user_password_path

    assert_select "h1", /Mot de passe oublié/
    assert_match "Il reste valable 6 heures.", response.body
    assert_select "label", "Email du compte"
    assert_select "a[href=?]", new_user_session_path, text: "Retour à la connexion"
  end

  test "requesting a link leads to the sent screen with the expiry hour, for any address" do
    post user_password_path, params: { user: { email: "alice@test.com" } }
    assert_redirected_to sent_user_password_path
    follow_redirect!

    assert_select "h1", "Vérifiez vos emails"
    assert_select "b", "alice@test.com"
    expires = users(:alice).zone.now + 6.hours
    assert_select "b", expires.strftime("%H:%M")
    assert_match "dans 6 heures", response.body
    assert_select "[data-controller=countdown] button[disabled]"
    assert_select "a[href=?]", new_user_session_path, text: "Retour à la connexion"

    reset!
    post user_password_path, params: { user: { email: "nobody@test.com" } }
    follow_redirect!
    assert_select "h1", "Vérifiez vos emails"
    assert_select "b", "nobody@test.com"
  end

  test "the sent screen without a request goes back to the form" do
    get sent_user_password_path
    assert_redirected_to new_user_password_path
  end

  test "the sent screen escapes the address it echoes" do
    post user_password_path, params: { user: { email: "<script>x</script>@test.com" } }
    follow_redirect!

    assert_no_match "<script>x", response.body
  end

  # --- A8 / A9 ----------------------------------------------------------

  test "a valid link shows the new password form for the account" do
    token = users(:alice).send_reset_password_instructions
    get edit_user_password_path(reset_password_token: token)

    assert_select "h1", "Nouveau mot de passe"
    assert_match "Pour le compte alice@test.com.", response.body
    assert_select "input[type=hidden][name='user[reset_password_token]'][value=?]", token
    assert_select "input[type=submit][value=?]", "Enregistrer et me connecter"
  end

  test "different passwords are reported under the confirmation field and keep the form" do
    token = users(:alice).send_reset_password_instructions
    put user_password_path, params: { user: { reset_password_token: token, password: "newpassword1", password_confirmation: "nope" } }

    assert_response :unprocessable_entity
    assert_field_error "Les deux mots de passe sont différents."
    assert_select "h1", "Nouveau mot de passe"
    assert_match "Pour le compte alice@test.com.", response.body
    assert_select "input[type=hidden][name='user[reset_password_token]'][value=?]", token
  end

  test "an expired link shows its send date and offers a new one" do
    token = users(:alice).send_reset_password_instructions
    sent_at = users(:alice).reload.reset_password_sent_at.in_time_zone(users(:alice).zone)

    travel 7.hours do
      get edit_user_password_path(reset_password_token: token)
    end

    assert_select "h1", "Ce lien a expiré"
    assert_match(/valables 6 heures\.\s+Celui-ci a été envoyé le #{sent_at.day} #{I18n.t("date.abbr_month_names")[sent_at.month]} à #{sent_at.strftime("%H:%M")}\./, response.body)
    assert_select "p", /Votre mot de passe actuel n'a pas changé\./
    assert_select "a[href=?]", new_user_password_path, text: "Recevoir un nouveau lien"
    assert_select "a[href=?]", new_user_session_path, text: "Retour à la connexion"
    assert_select "input[type=password]", 0
  end

  test "an unknown link shows the expired screen without a date" do
    get edit_user_password_path(reset_password_token: "nonsense")

    assert_select "h1", "Ce lien a expiré"
    assert_no_match(/Celui-ci a été envoyé/, response.body)
  end

  test "resetting the password signs in and says it without naming anyone" do
    token = users(:alice).send_reset_password_instructions
    put user_password_path, params: { user: { reset_password_token: token, password: "newpassword1", password_confirmation: "newpassword1" } }

    assert_redirected_to dashboard_path
    assert_equal "Votre mot de passe est modifié. La session est ouverte.", flash[:notice]
  end

  test "the account mails are in French and carry their link" do
    sign_up
    mail = ActionMailer::Base.deliveries.last
    assert_match "Confirmez votre adresse email pour 50/50", mail.body.to_s
    assert_match "24 heures", mail.body.to_s
    assert_no_match(/Welcome|confirm your/i, mail.body.to_s)

    users(:alice).send_reset_password_instructions
    mail = ActionMailer::Base.deliveries.last
    assert_match "6 heures", mail.body.to_s
    assert_no_match(/Someone has requested/, mail.body.to_s)
  end

  test "no wording of the account screens uses the point médian" do
    I18n.t("auth").to_s.then { |text| assert_no_match(/·e|\(e\)/, text) }
    assert_no_match(/·e/, File.read(Rails.root.join("config/locales/fr/devise.yml")))
  end
end
