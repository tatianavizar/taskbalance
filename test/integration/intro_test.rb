require "test_helper"

# I1 to I3 and the welcome screen A1.
class IntroTest < ActionDispatch::IntegrationTest
  test "the welcome screen offers the intro first, then goes straight to sign-up once it is seen" do
    get root_path
    assert_response :success
    assert_select "h1", "50/50"
    assert_select "a[href=?]", intro_path(1), text: "Découvrir 50/50"
    assert_select "a[href=?]", new_user_session_path, text: "J'ai déjà un compte"
    assert_select "a[href=?]", new_user_registration_path, 0

    get intro_path(1)
    get root_path
    assert_select "a[href=?]", new_user_registration_path, text: "Créer un compte"
    assert_select "a[href=?]", intro_path(1), 0
  end

  test "a signed-in person lands on the app, not on the welcome screen" do
    sign_in users(:alice)
    get root_path
    assert_redirected_to dashboard_path
  end

  test "the three intro screens are public, bare and lead to each other" do
    get intro_start_path
    assert_redirected_to intro_path(1)

    (1..3).each do |step|
      get intro_path(step)
      assert_response :success
      assert_select "h1", 1
      assert_select "nav.tab-bar", 0
      assert_select "[role=img][aria-label=?]", "Écran #{step} sur 3"
    end

    get intro_path(1)
    assert_select "a[href=?]", intro_path(2), text: "Suivant"
    assert_select "a[href=?]", new_user_registration_path, text: "Passer"
    get intro_path(2)
    assert_select "a[href=?]", intro_path(3), text: "Suivant"
    get intro_path(3)
    assert_select "a[href=?]", new_user_registration_path, text: "Continuer"
    assert_select "a", text: "Passer", count: 0
  end

  test "the rules quoted come from HouseholdRules, for two and for three members" do
    get intro_path(2)

    assert_match "40 – 60 %", response.body
    assert_match "entre 23 et 43 %", response.body
    assert_match "#{HouseholdRules::ULTIMATE_UNBALANCED_QUOTA} semaines déséquilibrées au plus", response.body
    HouseholdRules::LEVEL_THRESHOLDS.each { |weeks| assert_match "#{weeks} sem.", response.body }
  end

  test "the absence rule needs a single declaration and never names a gender" do
    get intro_path(3)

    assert_match "Une seule déclaration suffit", response.body
    assert_no_match(/\p{L}·\p{L}/, response.body)
  end

  test "an unknown step is a 404" do
    get intro_path(4)
    assert_response :not_found
  end

  test "reopened from the account, the intro returns to the account" do
    sign_in users(:alice)
    get intro_path(1)
    assert_select "a[href=?]", account_path, text: "Passer"
    get intro_path(3)
    assert_select "a[href=?]", account_path, text: "Terminer"
  end

  test "household rules follow the number of members" do
    assert_equal 50, HouseholdRules.fair_share(2)
    assert_equal 40..60, HouseholdRules.zone(2)
    assert_equal 23..43, HouseholdRules.zone(3)
  end
end
