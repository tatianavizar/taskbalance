require "test_helper"

# Lots 8b and 9, server side: the phone token, H1, the tap target, the
# universal link files.
class NativePushTest < ActionDispatch::IntegrationTest
  NATIVE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Hotwire Native iOS; Turbo Native iOS".freeze

  setup do
    @alice = users(:alice)
    @alice.update!(password: "password123")
  end

  def sign_in_for_real(headers: {})
    post user_session_path, params: { user: { email: @alice.email, password: "password123" } }, headers: headers
    assert_response :redirect
  end

  def register(token, platform: "ios")
    post push_device_path, params: { token: token, platform: platform }, as: :json, headers: { "User-Agent" => NATIVE_UA }
  end

  # ---- registration -----------------------------------------------------------

  test "a signed-in shell registers its token" do
    sign_in @alice
    register("phone-token")

    assert_response :no_content
    device = PushDevice.sole
    assert_equal [ @alice.id, "ios", "phone-token" ], [ device.user_id, device.platform, device.token ]
  end

  test "registration needs an account" do
    register("phone-token")

    assert_response :unauthorized
    assert_equal 0, PushDevice.count
  end

  test "registration is refused for an unknown platform" do
    sign_in @alice
    register("phone-token", platform: "web")

    assert_response :unprocessable_entity
  end

  test "registration needs the page's CSRF token, like any form" do
    ActionController::Base.allow_forgery_protection = true
    sign_in @alice
    register("phone-token")

    assert_response :unprocessable_entity
    assert_equal 0, PushDevice.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "a withdrawn permission unregisters the token" do
    sign_in @alice
    register("phone-token")
    delete push_device_path, params: { token: "phone-token" }, as: :json

    assert_response :no_content
    assert_equal 0, PushDevice.count
  end

  test "signing out unregisters this phone, not the person's other ones" do
    other = PushDevice.register!(@alice, token: "tablet", platform: "android")
    sign_in_for_real
    register("phone-token")
    assert_equal 2, PushDevice.count

    delete destroy_user_session_path

    assert_equal [ other.id ], PushDevice.pluck(:id)
  end

  # ---- the layout ---------------------------------------------------------------

  test "the shells get the token sync element, with the digest of the token this session registered" do
    sign_in @alice
    get dashboard_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "[data-controller='bridge--push-notifications'][data-bridge--push-notifications-mode-value='sync']" do |elements|
      assert_equal "", elements.first["data-bridge--push-notifications-device-digest-value"]
    end

    register("phone-token")
    get dashboard_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "[data-bridge--push-notifications-device-digest-value='#{PushDevice.digest("phone-token")}']"
  end

  test "a browser gets no bridge element" do
    sign_in @alice
    get dashboard_path

    assert_select "[data-controller='bridge--push-notifications']", 0
  end

  # ---- H1 -------------------------------------------------------------------------

  test "the intro ends on H1 in the shells, on sign-up in a browser" do
    get intro_path(3), headers: { "User-Agent" => NATIVE_UA }
    assert_select "a.btn-primary[href='#{push_permission_path}']"

    get intro_path(3)
    assert_select "a.btn-primary[href='#{new_user_registration_path}']"
  end

  test "H1 says what will be sent, with two buttons of the same weight" do
    get push_permission_path, headers: { "User-Agent" => NATIVE_UA }

    assert_response :success
    assert_select "h1", "Les notifications sur ce téléphone"
    assert_text "Pas de rappel quotidien, pas de relance pour enregistrer."
    assert_select "a.btn", 2
    assert_select "a.btn[href='#{new_user_registration_path}']", 2
    assert_equal [ "btn btn-outline flex-1" ], css_select("a.btn").map { |a| a["class"] }.uniq
    assert_select "[data-bridge--push-notifications-mode-value='ask'][data-bridge--push-notifications-signed-in-value='false']"
  end

  test "H1 reopened from the account goes back to it" do
    sign_in @alice
    get account_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "a[href='#{push_permission_path}']"

    get push_permission_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "a.btn[href='#{account_path}']", 2
  end

  test "a browser skips H1 and has no row for it" do
    get push_permission_path
    assert_redirected_to new_user_registration_path

    sign_in @alice
    get account_path
    assert_select "a[href='#{push_permission_path}']", 0
  end

  # ---- tap target ---------------------------------------------------------------------

  test "a tap opens the notification, which marks it read and lands on its screen" do
    household = households(:smith_home)
    notification = Notification.create!(user: @alice, household: household, kind: "weekly_report", event_type: "weekly_report",
                                        dedup_key: "weekly_report:test", facts: { "week_start" => "2026-11-02" },
                                        channel: "push", deliver_at: 1.hour.ago)
    sign_in @alice
    get notification_path(notification) # the "path" of the push payload (PushDeliveryTest)

    assert_redirected_to report_path(semaine: "2026-11-02")
    assert notification.reload.read?
  end

  # ---- tabs ------------------------------------------------------------------------------

  test "the Foyer tab has one address" do
    sign_in @alice
    get household_home_path
    assert_redirected_to household_path(@alice.household)

    sign_in users(:dana)
    get household_home_path
    assert_redirected_to new_household_path
  end

  test "the path configuration lists the four tabs" do
    get "/configurations/ios_v1.json"

    assert_equal %w[/dashboard /chores /bilan /foyer], response.parsed_body.dig("settings", "tabs").map { |tab| tab["path"] }
    assert_includes response.parsed_body["rules"].map { |r| r["patterns"] }.flatten, "/delete$"
    assert(response.parsed_body["rules"].none? { |r| r["properties"].key?("uri") })

    get "/configurations/android_v1.json"
    uris = response.parsed_body["rules"].map { |r| r.dig("properties", "uri") }
    assert_equal [ "hotwire://fragment/web", "hotwire://fragment/web/modal/sheet", nil ], uris
  end

  test "the configurations bundled in the apps match the server's" do
    ios = JSON.parse(Rails.root.join("native/ios/FiftyFifty/Resources/path-configuration.json").read)
    android = JSON.parse(Rails.root.join("native/android/app/src/main/assets/json/configuration.json").read)

    assert_equal JSON.parse(ConfigurationsController.path_configuration("ios").to_json)["rules"], ios["rules"]
    assert_equal JSON.parse(ConfigurationsController.path_configuration("android").to_json)["rules"], android["rules"]
  end

  # ---- universal links, App Links -------------------------------------------------------

  test "the apple-app-site-association file is JSON at both addresses, even for Apple's fetcher" do
    [ "/.well-known/apple-app-site-association", "/apple-app-site-association" ].each do |path|
      get path, headers: { "User-Agent" => "AASA-Bot/1.0.0" }

      assert_response :success
      assert_equal "application/json", response.media_type
      details = response.parsed_body.dig("applinks", "details").sole
      assert_equal [ "TEAMID0000.app.cinquante.mobile" ], details["appIDs"]
      components = details["components"]
      assert_equal({ "/" => "/desinscription/*", "exclude" => true }, components.first)
      assert_includes components, { "/" => "/invitations/*" }
      assert_includes components, { "/" => "/users/password/edit" }
    end
  end

  test "the team and bundle ids come from the ENV" do
    association = NativeApp.apple_app_site_association({ "APPLE_TEAM_ID" => "ABCDE12345", "IOS_BUNDLE_ID" => "app.x" })

    assert_equal [ "ABCDE12345.app.x" ], association.dig(:applinks, :details, 0, :appIDs)
  end

  test "assetlinks.json names the Android package and the signing fingerprints" do
    get "/.well-known/assetlinks.json", headers: { "User-Agent" => "Google-Digital-Asset-Links" }

    assert_response :success
    target = response.parsed_body.sole["target"]
    assert_equal "app.cinquante.mobile", target["package_name"]
    assert_equal [ NativeApp::FINGERPRINT_PLACEHOLDER ], target["sha256_cert_fingerprints"]

    links = NativeApp.asset_links({ "ANDROID_PACKAGE" => "app.y", "ANDROID_CERT_FINGERPRINTS" => "AA:BB, CC:DD" })
    assert_equal %w[AA:BB CC:DD], links.first.dig(:target, :sha256_cert_fingerprints)
  end

  # ---- bridge hooks in the views ------------------------------------------------------------

  test "date fields and the journal menu carry their bridge components" do
    sign_in @alice
    get new_member_pause_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "input[type=date][data-controller='bridge--date-picker']", minimum: 1

    log = ChoreLog.create!(user: @alice, household: @alice.household, chore_name: "Vaisselle", category: "cleaning",
                           mental_load: false, execution_load: true, time_spent: 10, completed_at: Time.current)
    get chore_logs_path, headers: { "User-Agent" => NATIVE_UA }
    assert_select "[data-controller='bridge--overflow-menu']" do
      assert_select "a[data-action='click->bridge--overflow-menu#open'][href='#{edit_chore_log_path(log)}']"
      assert_select "[hidden] a[data-bridge--overflow-menu-target=item]", 2
      assert_select "[hidden] a[data-destructive=true][href='#{delete_chore_log_path(log)}']"
    end
  end
end
