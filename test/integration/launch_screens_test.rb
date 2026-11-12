require "test_helper"

# Lot 10, part A: I4 (the rules screen), the legal pages and the cookie banner.
class LaunchScreensTest < ActionDispatch::IntegrationTest
  NATIVE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Hotwire Native iOS; Turbo Native iOS"

  def page_text
    CGI.unescapeHTML(response.body.gsub(/<[^>]+>/, " ")).squish
  end

  # ---- I4: Comment on calcule ? ------------------------------------------------

  test "I4 is public and carries the numbers of HouseholdRules" do
    get rules_path

    assert_response :success
    assert_select "h1", 1
    assert_select "nav.tab-bar", 0
    text = page_text

    (2..HouseholdMember::COLORS.size).each do |members|
      zone = HouseholdRules.zone(members)
      assert_select "#rules-zones tbody tr" do |rows|
        row = rows[members - 2]
        assert_equal "#{members} #{HouseholdRules.fair_share(members)} % de #{zone.min} à #{zone.max} %", row.text.squish
      end
    end
    assert_includes text, "#{HouseholdRules::LEVEL_THRESHOLDS[0...-1].join(", ")} puis #{HouseholdRules::LEVEL_THRESHOLDS.last} semaines équilibrées"
    assert_includes text, "au plus #{HouseholdRules::ULTIMATE_UNBALANCED_QUOTA} semaines non équilibrées sur les #{HouseholdRules::ULTIMATE_WINDOW_WEEKS} dernières"
    assert_includes text, "#{HouseholdRules::EMPTY_WEEKS_FOR_INQUIRY} semaines de suite : tout le foyer est interrogé"
    assert_includes text, "Réponse avant mercredi #{HouseholdRules::ABSENCE_DEADLINE_HOUR}:00"
    assert_includes text, "#{HouseholdRules::PAUSE_RETROACTIVE_DAYS} jours en arrière au plus"
    assert_includes text, "dimanche #{HouseholdRules::REPORT_PROVISIONAL_HOUR}:00"
    assert_includes text, "lundi #{HouseholdRules::REPORT_FINAL_HOUR}:00"
    assert_includes text, "39,5 % est hors de la zone de 40 à 60 %"
    assert_not_includes text, "85 %", "the ratio of 85 % was replaced by the quota of 7 on 52"
    assert_not_includes text, "points"
    assert_no_match(/\p{L}·\p{L}/, response.body)
  end

  test "I4 reads its numbers: change the constants and the screen follows" do
    original = HouseholdRules::ZONE
    HouseholdRules.send(:remove_const, :ZONE)
    HouseholdRules.const_set(:ZONE, 5)
    get rules_path
    assert_select "#rules-zones tbody tr:first-child td:last-child", text: "de 45 à 55 %"
    assert_includes page_text, "44,5 % est hors de la zone de 45 à 55 %"
  ensure
    HouseholdRules.send(:remove_const, :ZONE)
    HouseholdRules.const_set(:ZONE, original)
  end

  test "I4 is an accessible table and a definition list" do
    get rules_path

    assert_select "dl#rules dt", minimum: 6
    assert_select "table#rules-zones caption.sr-only"
    assert_select "table#rules-zones thead th[scope=col]", 3
    assert_select "table#rules-zones tbody th[scope=row]", HouseholdMember::COLORS.size - 1
  end

  test "I3 links to the rules, the account too, and the home's « Comment on calcule ? »" do
    get intro_path(3)
    assert_select "a[href=?]", rules_path, text: "Comment on calcule ?"
    assert_includes page_text, "au-delà de #{HouseholdRules::ULTIMATE_UNBALANCED_QUOTA} semaines déséquilibrées sur #{HouseholdRules::ULTIMATE_WINDOW_WEEKS}, retour au niveau 4"

    sign_in users(:alice)
    get account_path
    assert_select "a[href=?]", rules_path, text: /Comment on calcule/
    assert_select "a[href=?]", terms_path
    assert_select "a[href=?]", privacy_path
  end

  # ---- legal pages -----------------------------------------------------------------

  test "the CGU and the privacy policy are public, marked as drafts and have placeholders" do
    [ terms_path, privacy_path ].each do |path|
      get path

      assert_response :success
      assert_select "h1", 1
      assert_select "#legal-draft[role=note]", text: /Brouillon, à valider juridiquement/
      assert_select ".legal-todo", minimum: 3
      assert_select "nav.tab-bar", 0
    end
  end

  test "the privacy policy says what the app does: data, ownership, deletion, emails, no tracker, hosting to fill" do
    get privacy_path
    text = page_text

    assert_includes text, "Quand vous quittez un foyer, vos enregistrements sont détachés du foyer et restent à vous"
    assert_includes text, "Quand vous supprimez votre compte, vos enregistrements, vos préférences et vos pauses sont supprimés"
    assert_includes text, "Ancien membre"
    assert_includes text, "aucun outil de mesure d'audience"
    assert_includes text, "strictement nécessaires"
    assert_includes text, "[À COMPLÉTER : nom, adresse et pays de l'hébergeur]"
    assert_includes text, "confirmation, mot de passe oublié, invitations"
    assert_includes text, "Les polices de caractères sont servies par l'appli elle-même"
    assert_not_includes text, "Google Fonts"
    assert_no_match(/\p{L}·\p{L}/, response.body)
  end

  test "the legal pages invent no company: every identity field is a placeholder" do
    get terms_path
    assert_includes page_text, "[À COMPLÉTER : nom ou raison sociale]"
    assert_includes page_text, "[À COMPLÉTER : adresse]"
    assert_includes page_text, "[À COMPLÉTER : adresse email de contact]"
    assert_no_match(/\bSAS\b|\bSARL\b|SIRET\s*:?\s*\d/, response.body)
  end

  test "A2 links to both pages without pre-ticking anything" do
    get new_user_registration_path

    assert_select "#legal-notice a[href=?]", terms_path, text: "conditions d'utilisation"
    assert_select "#legal-notice a[href=?]", privacy_path, text: "politique de confidentialité"
    assert_select "input[type=checkbox][checked]", 0
  end

  test "the legal pages link back to each other and the account has both links" do
    get terms_path
    assert_select "a[href=?]", privacy_path
    get privacy_path
    assert_select "a[href=?]", terms_path
  end

  # ---- cookie banner -------------------------------------------------------------------

  test "the banner informs, links to the privacy page and has a single OK; no toggle" do
    get root_path

    assert_select "aside#cookie-banner[role=region][aria-label=Cookies]" do
      assert_select "a[href=?]", privacy_path, text: "En savoir plus"
      assert_select "button", count: 1
      assert_select "button", text: "OK"
      assert_select "input[type=checkbox], [role=switch]", 0
    end
    assert_includes page_text, "Aucun traceur"
  end

  test "OK remembers the dismissal in a necessary cookie and the banner is gone" do
    post cookie_notice_path

    assert_redirected_to root_path
    assert_equal "1", cookies[:cookie_notice_seen]
    assert_match(/cookie_notice_seen=1;.*httponly/i, response.headers["Set-Cookie"])
    assert_match(/samesite=lax/i, response.headers["Set-Cookie"])
    follow_redirect!
    assert_select "#cookie-banner", 0
    get terms_path
    assert_select "#cookie-banner", 0
  end

  test "OK answers a Turbo Stream that removes the banner without leaving the page" do
    post cookie_notice_path, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=remove][target=cookie-banner]"
  end

  test "the banner sits above the tab bar when the tab bar shows and is on every screen until dismissed" do
    sign_in users(:alice)
    get dashboard_path
    assert_select "aside#cookie-banner.with-tabs"
    get account_path
    assert_select "aside#cookie-banner"
  end

  test "the banner is hidden in the Hotwire Native shells" do
    get root_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "#cookie-banner", 0
    get privacy_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "#cookie-banner", 0
  end

  test "the app sets only necessary cookies: nothing but the session, the intro and the banner" do
    get intro_path(1)
    names = Array(response.headers["Set-Cookie"]).join("\n").scan(/^([^=\n]+)=/).flatten
    assert_equal [ "intro_seen" ], names.reject { |name| name.include?("session") }
  end
end
