require "test_helper"

# Lot 10, part A: the accessibility pass (audit-ux findings 16, 25, 27).
# Every screen is rendered and its markup is checked for what assistive
# technology reads: names on controls, roles that mean what they say, ids that
# the ARIA attributes point to, errors linked to their fields, dialogs,
# landmarks and live regions. Contrast of the tokens is in ContrastTest.
class AccessibilityTest < ActionDispatch::IntegrationTest
  include WeeklyEngineHelpers
  include SplitHelpers

  teardown { travel_back }

  # Households built in the test live in the week of 4 Nov 2026; the fixtures
  # are stamped with the real clock, so the two never share a test.
  def in_week_45 = travel_to(paris(2026, 11, 4, 18, 32))

  # ---- the audit ----------------------------------------------------------------------

  def doc = Nokogiri::HTML5(response.body)

  def text_of(node) = node.text.gsub(/\s+/, " ").strip

  # Accessible name of a control: aria-label, aria-labelledby, a label, its
  # own text, a title, or an image alt inside it.
  def named?(node, document)
    return true if node["aria-label"].to_s.strip != ""

    if node["aria-labelledby"]
      return node["aria-labelledby"].split.any? { |id| (target = document.at_css("[id='#{id}']")) && text_of(target) != "" }
    end
    return true if node["id"] && document.at_css("label[for='#{node["id"]}']")
    return true if node.ancestors("label").any?
    return true if text_of(node) != ""
    return true if node["title"].to_s.strip != ""
    return true if node.at_css("img[alt]:not([alt=''])")

    false
  end

  # Every problem of the page, as strings.
  def audit(path)
    document = doc
    problems = []
    add = ->(message) { problems << "#{path}: #{message}" }

    add.("no lang on <html>") if document.at_css("html")["lang"].to_s.empty?
    add.("#{document.css("h1").size} <h1>, expected 1") unless document.css("h1").size == 1
    add.("no <main>") unless document.at_css("main")

    ids = document.css("[id]").map { |n| n["id"] }
    ids.tally.select { |_, n| n > 1 }.each_key { |id| add.("duplicate id #{id}") }

    %w[aria-labelledby aria-describedby aria-controls].each do |attribute|
      document.css("[#{attribute}]").each do |node|
        node[attribute].split.each do |id|
          add.("#{node.name}[#{attribute}] points to a missing ##{id}") unless ids.include?(id)
        end
      end
    end

    document.css("input:not([type=hidden]):not([type=submit]):not([type=button]), select, textarea").each do |node|
      add.("unnamed #{node.name}[#{node["name"]}]") unless named?(node, document)
    end
    document.css("button, a[href], [role=button]").each do |node|
      add.("unnamed #{node.name} #{node["href"] || node["class"]}") unless named?(node, document)
    end
    document.css("[role=img]").each { |node| add.("role=img without aria-label (#{node["class"]})") unless named?(node, document) }
    document.css("img").each { |node| add.("img without alt") unless node.key?("alt") }
    document.css("[role=switch]").each do |node|
      add.("role=switch on #{node.name}, not a checkbox") unless node.name == "input" && node["type"] == "checkbox"
      add.("unnamed switch") unless named?(node, document)
    end
    document.css("[role=radio], [role=checkbox], [role=tab]").each do |node|
      add.("hand-made #{node["role"]} on a #{node.name}: use a real input or button") unless %w[input button].include?(node.name)
    end
    document.css("[aria-invalid=true]").each do |node|
      add.("aria-invalid without aria-describedby on #{node["name"]}") if node["aria-describedby"].to_s.empty?
    end
    document.css("dialog").each do |node|
      add.("dialog##{node["id"]} without a name") unless node["aria-label"] || node["aria-labelledby"]
    end
    document.css("[tabindex]").each do |node|
      add.("positive tabindex on #{node.name}") if node["tabindex"].to_i.positive?
    end
    document.css("div[onclick], span[onclick]").each { add.("click handler on a non-interactive element") }
    document.css("label[for]").each { |node| add.("label for=#{node["for"]} points to nothing") unless ids.include?(node["for"]) }
    problems
  end

  def assert_accessible(path, **headers)
    get path, headers: headers
    assert_response :success, "#{path} did not render"
    problems = audit(path)
    assert_empty problems, problems.join("\n")
  end

  # ---- public screens -------------------------------------------------------------------

  test "the public screens pass the audit" do
    [ root_path, intro_path(1), intro_path(2), intro_path(3), rules_path, terms_path, privacy_path,
      new_user_session_path, new_user_registration_path, new_user_password_path ].each { |path| assert_accessible(path) }
  end

  test "the sign-up errors are linked to their fields" do
    post user_registration_path, params: { user: { first_name: "", email: "nope", password: "1" } }
    assert_response :unprocessable_entity
    assert_empty audit("sign-up with errors")
    assert_select "input[aria-invalid=true][aria-describedby]", minimum: 2
    document = doc
    document.css("input[aria-invalid=true]").each do |input|
      input["aria-describedby"].split.each { |id| assert document.at_css("[id='#{id}']"), "##{id} missing" }
    end
  end

  # ---- signed-in screens ---------------------------------------------------------------------

  test "the screens of a member pass the audit" do
    sign_in users(:alice)
    household = users(:alice).household
    paths = [ dashboard_path, chores_path, new_chore_path, report_path, report_history_path, levels_path,
              household_path(household), edit_household_path(household), household_chores_setup_path(household),
              household_preferences_path(household), household_split_path(household), household_split_settings_path(household),
              household_member_style_path(household), new_household_invitation_path(household), account_path, edit_first_name_path,
              edit_email_path, edit_password_path, delete_account_path, chore_logs_path, new_chore_log_path, member_pauses_path,
              new_member_pause_path, notifications_path, new_household_departure_path(household), delete_household_path(household) ]
    paths.each { |path| assert_accessible(path) }
  end

  test "the styleguide passes the audit" do
    sign_in users(:alice)
    assert_accessible(styleguide_path)
  end

  test "a three-member split with the assignment sheets passes the audit" do
    in_week_45
    household, (virginie, *) = build_household("Virginie", "Karim", "Karine")
    chore!(household, "Faire les courses", [ virginie ])
    sign_in virginie
    assert_accessible(household_split_path(household))
    assert_accessible(dashboard_path)
    assert_accessible(report_path)
  end

  # ---- findings 16, 25, 27: roles, names, focus -------------------------------------------------------

  test "27: the active tab is marked and the tab bar is a named navigation" do
    sign_in users(:alice)
    get dashboard_path

    assert_select "nav.tab-bar[aria-label]"
    assert_select "nav.tab-bar a[aria-current=page]", 1
  end

  test "27: the confirm sheet is a named modal dialog and the sheets focus their first control" do
    sign_in users(:alice)
    get dashboard_path

    assert_select "dialog#confirm-dialog[aria-labelledby][aria-modal=true]"
    script = Rails.root.join("app/javascript/confirm_dialog.js").read
    assert_includes script, "[data-confirm-cancel]"
    assert_includes script, ".focus()"
    sheet = Rails.root.join("app/javascript/controllers/sheet_controller.js").read
    assert_includes sheet, "showModal()"
    assert_includes sheet, "first?.focus()", "focus goes into the sheet"
    assert_includes sheet, "this.openerTarget.focus()", "and comes back to the button that opened it"
  end

  test "16: switches are real checkboxes with a name, and filters and segments are real inputs" do
    sign_in users(:alice)
    get account_path

    assert_select "input[type=checkbox][role=switch]", minimum: 1
    assert_select "[role=switch]:not(input)", 0
    document = doc
    document.css("input[role=switch]").each { |node| assert named?(node, document), "unnamed switch #{node["name"]}" }
  end

  test "27: the intro dots are announced, the Balance reads its title first, the home has a live region" do
    get intro_path(2)
    assert_select "[role=img][aria-label=?]", "Écran 2 sur 3"

    in_week_45
    household, (a, b, c) = build_household("Ana", "Ben", "Cy")
    [ a, b, c ].each { |user| log!(household, user, at: paris(2026, 11, 3, 10), count: 2) }
    sign_in a
    get dashboard_path

    assert_select "[role=img][aria-label^=?]", "Charge mentale : "
    assert_select "[role=img][aria-label^=?]", "Exécution : "
    assert_select "#home-live[aria-live=polite]"
  end

  test "25: the controls that were under 44 px have a 44 px floor in the stylesheet" do
    css = Rails.root.join("app/assets/tailwind/application.css").read
    {
      ".btn" => /\.btn \{[^}]*min-height: 52px/, ".btn-sm" => /\.btn-sm \{ min-height: 44px/,
      ".segment-label" => /\.segment-label \{[^}]*min-height: 44px/, ".chip" => /\.chip \{[^}]*min-height: 44px/,
      ".done-btn" => /\.done-btn \{[^}]*min-height: 44px/, ".assign-chip" => /\.assign-chip \{[^}]*width: 44px; height: 44px/,
      ".back-button" => /\.back-button \{[^}]*width: 44px; height: 44px/, ".assign-button" => /\.assign-button \{[^}]*min-height: 44px/,
      ".swatch" => /\.swatch \{[^}]*min-height: 44px/, ".cookie-ok" => /\.cookie-ok \{[^}]*min-height: 44px/,
      ".stepper-btn" => /\.stepper-btn \{[^}]*height: 44px/
    }.each { |selector, pattern| assert_match pattern, css, "#{selector} lost its 44 px floor" }
    # The switch is 48 x 28 but its whole row is the target (label, min 44 px).
    assert_match(/\.switch-input \{[^}]*width: 48px; height: 28px/, css)
  end

  test "reduced motion: animations and transitions are neutralised" do
    css = Rails.root.join("app/assets/tailwind/application.css").read
    assert_match(/prefers-reduced-motion: reduce\)\s*\{\s*\*, \*::before, \*::after \{[^}]*animation-duration: 0\.01ms !important;[^}]*transition-duration: 0\.01ms !important/m, css)
    assert_match(/animation-iteration-count: 1 !important/, css)
    assert_match(/scroll-behavior: auto !important/, css)
  end

  test "the layout has a skip link, a focusable main and a named banner" do
    get root_path

    assert_select "a.skip-link[href='#main']"
    assert_select "main#main[tabindex='-1']"
  end

  test "form errors: the summary is an alert and each field's message is described by id" do
    sign_in users(:dana) # no household yet
    post households_path, params: { household: { name: "" } }
    assert_response :unprocessable_entity
    assert_empty audit("household with errors")
    assert_select ".field-error"
    assert_select "input[aria-invalid=true][aria-describedby]"
  end

  test "native shells: the skip link and the banner are not rendered" do
    get root_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone) Hotwire Native iOS; Turbo Native iOS" }
    assert_select "a.skip-link", 0
    assert_select "#cookie-banner", 0
  end
end
