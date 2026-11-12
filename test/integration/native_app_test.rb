require "test_helper"

class NativeAppTest < ActionDispatch::IntegrationTest
  NATIVE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Hotwire Native iOS; Turbo Native iOS"
  OLD_CHROME_UA = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"

  setup do
    sign_in users(:alice)
    @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed }

  test "the HTML header and tab bar are rendered in a regular browser" do
    get dashboard_path

    assert_response :success
    assert_select "nav.tab-bar a.tab-item", 4
    assert_select "nav.tab-bar a[aria-current=page]", text: /Accueil/
    assert_select "header.app-header"
  end

  test "the HTML header and tab bar are not rendered for the native app" do
    get dashboard_path, headers: { "User-Agent" => NATIVE_UA }

    assert_response :success
    assert_select "nav.tab-bar", 0
    assert_select "header.app-header", 0
  end

  test "the back button is not rendered for the native app" do
    sign_in users(:dana) # no household yet, so the creation screen renders
    get new_household_path, headers: { "User-Agent" => NATIVE_UA }

    assert_response :success
    assert_select "a.back-button", 0

    get new_household_path
    assert_select "a.back-button", 1
  end

  test "allow_browser blocks an old browser but never the native app" do
    get dashboard_path, headers: { "User-Agent" => OLD_CHROME_UA }
    assert_response :not_acceptable

    get dashboard_path, headers: { "User-Agent" => "#{OLD_CHROME_UA} Hotwire Native Android" }
    assert_response :success
  end

  test "the path configuration is valid JSON for iOS and Android" do
    %w[ios android].each do |platform|
      get "/configurations/#{platform}_v1.json"

      assert_response :success
      assert_equal "application/json", response.media_type
      config = response.parsed_body
      assert config["settings"].is_a?(Hash)

      rules = config["rules"]
      assert rules.all? { |r| r["patterns"].is_a?(Array) && r["properties"].is_a?(Hash) }
      assert_equal "default", rules.first["properties"]["context"]

      modal = rules.find { |r| r["properties"]["context"] == "modal" }
      assert_equal [ "/new$", "/edit$", "/completion/new$", "/delete$", "/cancel$" ], modal["patterns"]

      none = rules.find { |r| r["properties"]["presentation"] == "none" }
      assert_includes none["patterns"], "/recede_historical_location$"
    end
  end

  test "the path configuration is served without being signed in" do
    sign_out :user
    get "/configurations/ios_v1.json"

    assert_response :success
  end

  test "an unknown page renders the French 404 page without tab bar" do
    get "/cette-page-nexiste-pas"

    assert_response :not_found
    assert_select "h1", "Page introuvable"
    assert_select "nav.tab-bar", 0
  end

  test "the report tab shows the empty state" do
    get report_path

    assert_response :success
    assert_select "h1", "Bilan"
    assert_match "Le premier bilan arrive lundi", response.body
    assert_select "nav.tab-bar a[aria-current=page]", text: /Bilan/
  end

  test "the manifest is named 50/50" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    assert_equal "50/50", response.parsed_body["name"]
  end
end
