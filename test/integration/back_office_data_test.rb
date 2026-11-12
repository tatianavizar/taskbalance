require "test_helper"

# What the team sees (and does not): lists and pages render, show the listed
# columns, and no route reaches a log, a preference or a per-member figure.
class BackOfficeDataTest < ActionDispatch::IntegrationTest
  FORBIDDEN = %w[
    chore_log chore_preference household_week week_plan split_gap notification
    engine_event member_pause absence week_correction level_change approval
  ].freeze

  setup do
    sign_in_team!
    @household = households(:smith_home)
    @alice = users(:alice)
  end

  test "no admin route exposes a log, a preference or a per-member figure" do
    admin_paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }.grep(%r{\A/admin})
    assert_not_empty admin_paths
    FORBIDDEN.each do |name|
      assert_empty admin_paths.grep(/#{name}/), "an admin route mentions #{name}"
    end
  end

  test "the back office registers exactly the four read-only resources and the dashboard" do
    resources = ActiveAdmin.application.namespaces[:admin].resources.map { |resource| resource.resource_name.to_s }
    assert_equal %w[AdminAction Household Invitation User].sort, (resources - [ "Dashboard" ]).sort
    # ActiveAdmin's own Comment resource (routed even with comments off) is removed.
    assert_not_includes resources, "Comment"
    assert_empty Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(%r{/admin/comments})
  end

  test "the resources are read-only: no new, edit, update, destroy or batch route" do
    paths = Rails.application.routes.routes.select { |r| r.path.spec.to_s.start_with?("/admin") }
                 .map { |r| [ r.verb, r.path.spec.to_s.sub("(.:format)", "") ] }
    assert_empty paths.select { |_, path| path.end_with?("/new", "/edit", "/batch_action") }
    writes = paths.select { |verb, _| %w[POST PUT PATCH DELETE].include?(verb) }.map(&:last)
    allowed = %w[/admin/users/:id/confirm_current_email /admin/users/:id/confirm_pending_email /admin/users/:id/delete_account
                 /admin/users/:id/unlock_account
                 /admin/households/:id/unblock
                 /admin/invitations/:id/resend /admin/invitations/:id/cancel
                 /admin/login /admin/logout /admin/two_factor /admin]
    assert_empty writes - allowed
  end

  test "an unknown record type cannot be reached through a filter" do
    get "/admin/users", params: { q: { chore_logs_time_spent_gt: 0 } }
    assert_response :success
    get "/admin/users", params: { q: { household_membership_household_name_cont: "Smith" } }
    assert_response :success
    # A filter on an association is ignored, not applied: nobody can narrow the
    # list down by what a log or a household says.
    assert_text "alice@test.com"
    assert_text "bob@test.com"
  end

  test "dashboard: counts of accounts, households, pending invitations, households by state" do
    Invitation.invite(household: @household, email: "k@example.com", inviter: @alice, first_name: "K")
    households(:jones_home).update!(state: "blocked", blocked_at: Time.current)

    get "/admin"
    assert_response :success
    assert_select "[data-test-figure='Comptes']", User.count.to_s
    assert_select "[data-test-figure='Foyers']", Household.count.to_s
    assert_select "[data-test-figure='Invitations en cours']", "1"
    assert_text "Foyers par état"
    assert_text "Bloqué"
  end

  test "users: the listed columns, nothing else" do
    get "/admin/users"
    assert_response :success
    %w[Prénom Email Confirmé Foyer].each { |header| assert_select "th", text: /#{header}/ }
    assert_select "th", text: /Créé le/
    assert_select "th", text: /Supprimé le/
    assert_text "alice@test.com"
    assert_text "Smith Home"
    assert_no_match(/encrypted_password|\$2a\$/, response.body)

    get "/admin/users/#{@alice.id}"
    assert_response :success
    assert_text "Alice"
    assert_text "Smith Home"
    assert_no_match(/encrypted_password|\$2a\$|reset_password|confirmation_token/, response.body)
  end

  test "users: scopes and read-only (a PATCH or DELETE has no route)" do
    get "/admin/users", params: { scope: "email_a_confirmer" }
    assert_response :success
    assert_text "dana@test.com"
    assert_no_match(/alice@test.com/, response.body)

    patch "/admin/users/#{@alice.id}", params: { user: { first_name: "X" } }
    assert_response :not_found
    delete "/admin/users/#{@alice.id}"
    assert_response :not_found
    assert_equal "Alice", @alice.reload.first_name
    get "/admin/users/new"
    assert_response :not_found
  end

  test "households: name, zone, members, level, state, blocked since, final weeks, last activity" do
    block_time = Time.zone.local(2026, 11, 2, 9)
    @household.update!(state: "blocked", blocked_at: block_time, level: 2)
    HouseholdWeek.insert!({ household_id: @household.id, week_start: Date.new(2026, 10, 19), status: "final", outcome: "balanced",
                            time_zone: "Europe/Paris", computed_at: Time.current, members: [], created_at: Time.current, updated_at: Time.current })
    ChoreLog.create!(user: @alice, chore: chores(:smith_custom), household: @household, mental_load: true,
                     execution_load: false, time_spent: 5, completed_at: Time.zone.local(2026, 11, 5, 10))

    get "/admin/households"
    assert_response :success
    %w[Nom Fuseau Membres Niveau État Bloqué Semaines Dernière].each { |header| assert_select "th", text: /#{header}/ }
    row = css_select("tr").find { |tr| tr.text.include?("Smith Home") }
    assert row, "Smith Home is listed"
    cells = row.css("td").map { |td| td.text.squish }
    assert_includes cells, "Europe/Paris"
    assert_includes cells, "2"
    assert_includes cells, "Bloqué"
    assert_includes cells, "1"
    assert_includes cells, "semaine 45"
    assert_not_includes cells.join(" "), "5 novembre", "the day of a log is never shown"

    get "/admin/households/#{@household.id}"
    assert_response :success
    assert_text "Membres"
    assert_text "Alice"
    assert_select "a", text: "Débloquer le foyer"
  end

  test "households: the unblock button only shows for a blocked household" do
    get "/admin/households/#{@household.id}"
    assert_select "a", text: "Débloquer le foyer", count: 0
  end

  test "households: the blocked scope and the sort columns work" do
    households(:jones_home).update!(state: "blocked", blocked_at: Time.current)
    get "/admin/households", params: { scope: "bloques" }
    assert_response :success
    assert_text "Jones Home"
    assert_no_match(/Smith Home/, response.body)

    %w[name_asc level_desc state_asc blocked_at_desc created_at_desc].each do |order|
      get "/admin/households", params: { order: order }
      assert_response :success, order
    end
    get "/admin/households", params: { order: "member_count_desc" }
    assert_response :success
  end

  test "invitations: first name, email, state, dates, resend count; never the token" do
    invitation = Invitation.invite(household: @household, email: "karim@example.com", inviter: @alice, first_name: "Karim")
    get "/admin/invitations"
    assert_response :success
    assert_text "Karim"
    assert_text "karim@example.com"
    assert_text "En cours"
    %w[Renvois Envoyée Expire].each { |header| assert_select "th", text: /#{header}/ }
    assert_no_match(/#{Regexp.escape(invitation.token)}/, response.body)

    get "/admin/invitations/#{invitation.id}"
    assert_response :success
    assert_text "Renvoyer l'invitation"
    assert_text "Annuler l'invitation"
    assert_no_match(/#{Regexp.escape(invitation.token)}/, response.body)

    invitation.cancel!
    get "/admin/invitations/#{invitation.id}"
    assert_text "Annulée"
    assert_select "a", text: "Renvoyer l'invitation", count: 0
  end

  test "an expired invitation reads as expired in the list" do
    invitation = Invitation.invite(household: @household, email: "late@example.com", inviter: @alice, first_name: "Late")
    invitation.update_columns(expires_at: 1.day.ago)
    get "/admin/invitations"
    assert_text "Expirée"
  end

  test "pages never mention logs, preferences or shares" do
    ChoreLog.create!(user: @alice, chore: chores(:smith_custom), household: @household, mental_load: true,
                     execution_load: false, time_spent: 5, completed_at: Time.current)
    [ "/admin", "/admin/users", "/admin/households", "/admin/households/#{@household.id}", "/admin/users/#{@alice.id}" ].each do |path|
      get path
      assert_response :success, path
      assert_no_match(/mental_load|execution_load|time_spent|mental_share|chore_preference/, response.body, path)
    end
  end

  test "the stylesheet and layout are the back office's own: 50/50 fonts, no dark-mode script" do
    get "/admin"
    assert_select "link[rel=stylesheet][href*='active_admin']"
    assert_select "script", text: /localStorage\.theme/, count: 0
    assert_select "meta[name=robots][content*=noindex]"
  end
end
