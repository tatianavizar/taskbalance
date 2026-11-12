require "test_helper"

# Every page carries a strict Content-Security-Policy, and nothing the pages
# need (importmap, Turbo, Stimulus, the confirm dialog, the cookie banner)
# falls outside it.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  setup { @household = households(:smith_home) }

  def policy
    header = response.headers["Content-Security-Policy"]
    assert header.present?, "no Content-Security-Policy header"
    header.split(";").map(&:strip).to_h { |directive| directive.split(" ", 2).then { |name, value| [ name, value.to_s ] } }
  end

  def nonce
    response.body[/<meta name="csp-nonce" content="([^"]+)"/, 1]
  end

  # Inline <script> and <style> elements must carry the page's nonce; external
  # ones must come from this origin.
  def assert_page_within_policy(path)
    page_nonce = nonce
    assert page_nonce.present?, "#{path}: no csp-nonce meta tag"
    html = Nokogiri::HTML(response.body)

    html.css("script").each do |script|
      if script["src"]
        assert script["src"].start_with?("/"), "#{path}: external script #{script['src']}"
      else
        assert_equal page_nonce, script["nonce"], "#{path}: inline script without the nonce"
      end
    end
    html.css("style").each { |style| assert_equal page_nonce, style["nonce"], "#{path}: <style> without the nonce" }
    html.css("link[rel=stylesheet], link[rel=modulepreload]").each do |link|
      assert link["href"].start_with?("/"), "#{path}: external #{link['rel']} #{link['href']}"
    end
    html.css("[onclick], [onload], [onsubmit], [onchange], a[href^='javascript:']").each do |node|
      flunk "#{path}: inline event handler on #{node.name}"
    end
    html.css("form[action]").each do |form|
      assert form["action"].start_with?("/"), "#{path}: form posts off-site to #{form['action']}"
    end
  end

  test "the policy is strict: same origin only, no inline script, no framing" do
    get new_user_session_path
    directives = policy

    assert_equal "'self'", directives["default-src"]
    assert_equal "'self' 'nonce-#{nonce}'", directives["script-src"]
    assert_equal "'self' 'nonce-#{nonce}'", directives["style-src"]
    assert_equal "'unsafe-inline'", directives["style-src-attr"]
    assert_equal "'self'", directives["font-src"]
    assert_equal "'self' data:", directives["img-src"]
    assert_match(/\A'self' ws:/, directives["connect-src"])
    assert_equal "'none'", directives["frame-ancestors"]
    assert_equal "'self'", directives["base-uri"]
    assert_equal "'self'", directives["form-action"]
    assert_equal "'none'", directives["object-src"]
    assert_no_match(/unsafe-inline|unsafe-eval/, directives["script-src"])
    assert_no_match(/unsafe-inline/, directives["style-src"])
  end

  test "importmap, Turbo and Stimulus load under the policy, with the nonce" do
    get new_user_session_path

    assert_select "script[type=importmap][nonce='#{nonce}']"
    assert_select "script[type=module][nonce='#{nonce}']"
    assert_select "link[rel=modulepreload][href*=turbo]"
    assert_select "link[rel=modulepreload][href*=stimulus]"
  end

  test "the nonce stays the same across Turbo visits of a session" do
    get root_path # first visit: no session cookie yet
    first = nonce
    assert first.present?
    get new_user_registration_path

    assert_equal first, nonce
  end

  test "public pages, the cookie banner and the legal pages stay within the policy" do
    [ root_path, new_user_session_path, new_user_registration_path, new_user_password_path,
      terms_path, privacy_path ].each do |path|
      get path
      assert_response :success, path
      assert_page_within_policy(path)
    end
    get root_path
    assert_select "#cookie-banner form[action='/cookies']"
  end

  test "signed-in pages, the confirm dialog included, stay within the policy" do
    sign_in users(:alice)
    chore = chores(:smith_cooking)

    [ dashboard_path, report_path, report_history_path, levels_path, chores_path, chore_path(chore),
      new_chore_log_path(chore_id: chore.id), chore_logs_path, household_path(@household),
      household_split_path(@household, mode: "now"), account_path, notifications_path ].each do |path|
      get path
      assert_response :success, path
      assert_page_within_policy(path)
    end
    assert_select "dialog"
  end
end
