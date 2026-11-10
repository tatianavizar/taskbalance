require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  setup do
    @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed }

  test "sign up, create the household, log in again, invite someone and log a task" do
    visit root_url
    click_on "Découvrir 50/50"
    click_on "Passer"

    fill_in "Prénom", with: "Virginie"
    fill_in "Email", with: "virginie@exemple.fr"
    fill_in "Mot de passe", with: "motdepasse"
    click_on "Créer mon compte"
    assert_selector "h1", text: "Confirmez votre email"

    # La confirmation ne bloque pas : on crée le foyer sans attendre
    click_on "J'ai confirmé, continuer"
    fill_in "Nom du foyer", with: "Chez Virginie et Karim"
    click_on "Continuer", class: "btn"
    assert_text "Foyer créé."
    assert_selector "h1", text: "Chez Virginie et Karim"

    # Déconnexion (session supprimée), puis connexion
    page.driver.browser.manage.delete_all_cookies
    visit new_user_session_url
    assert_selector "h1", text: "Se connecter"
    fill_in "Email", with: "virginie@exemple.fr"
    fill_in "Mot de passe", with: "motdepasse"
    click_on "Se connecter", class: "btn"
    assert_selector "h1", text: "Accueil"
    visit household_url(Household.find_by!(name: "Chez Virginie et Karim"))

    # Invitation
    click_on "Inviter un membre"
    fill_in "Email de la personne à inviter", with: "karim@exemple.fr"
    click_on "Envoyer l'invitation"
    assert_text "Invitation envoyée à karim@exemple.fr."

    # Choix d'une tâche puis enregistrement
    click_on "Choisir les tâches"
    check tasks(:cook_meal).name, allow_label_click: true
    click_on "Enregistrer les tâches"
    assert_text "Tâches du foyer mises à jour."

    within("nav.tab-bar") { click_on "Tâches" }
    click_on "Fait"
    check "Exécution : le faire physiquement", allow_label_click: true
    fill_in "Temps passé (minutes)", with: "30"
    click_on "Enregistrer", class: "btn"
    assert_text "Enregistré : #{tasks(:cook_meal).name}."
  end

  test "an unknown page shows the French 404 page" do
    visit "/cette-page-nexiste-pas"

    assert_selector "h1", text: "Page introuvable"
    assert_text "Erreur 404"
    assert_no_selector "nav.tab-bar"
  end

  test "the styleguide renders every component" do
    visit styleguide_url

    %w[sg-logo sg-buttons sg-forms sg-cards sg-balance sg-cta sg-tabs].each do |id|
      assert_selector "##{id}"
    end
    assert_selector "svg[width='72'][aria-hidden='true']"
    assert_selector "a.back-button[aria-label='Retour']"
    assert_selector "[role=img][aria-label*='Virginie 71 %']", count: 1
    assert_selector "[role=switch]"
    assert_selector "nav.tab-bar a", count: 4
    assert_selector "nav.tab-bar a[aria-current=page]", text: "Bilan"
    assert_text "1 semaine équilibrée sur 3 pour le niveau 2"
  end

  test "a destructive action asks for confirmation in a sheet, not a browser dialog" do
    visit styleguide_url
    click_on "Ouvrir la confirmation"

    assert_selector "dialog[open] [data-confirm-message]", text: "Supprimer cette tâche ?"
    within("dialog[open]") { click_on "Annuler" }
    assert_no_selector "dialog[open]"
  end
end
