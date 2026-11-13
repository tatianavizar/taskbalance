require "test_helper"

# The two back-office roles (decision of 2026-11-13): a superadmin has every
# right, manages the team and reads a person's individual data, each reading
# logged; a plain admin keeps the aggregates-only back office.
class BackOfficeRolesTest < ActionDispatch::IntegrationTest
  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
  end

  def last_entry
    AdminAction.order(:id).last
  end

  def add_individual_data!
    ChoreLog.create!(user: @alice, chore: chores(:smith_custom), household: @household, mental_load: true,
                     execution_load: false, time_spent: 37, completed_at: Time.current, chore_name: "Rendez-vous pédiatre")
    ChorePreference.create!(user: @alice, chore: chores(:smith_custom), choice: "dislike")
    HouseholdWeek.insert!({ household_id: @household.id, week_start: Date.new(2026, 10, 19), status: "final", outcome: "unbalanced",
                            time_zone: "Europe/Paris", computed_at: Time.current, created_at: Time.current, updated_at: Time.current,
                            members: [ { "user_id" => @alice.id, "first_name" => "Alice", "mental_share" => 71, "execution_share" => 64, "logs_count" => 9 } ] })
    SplitGapEntry.create!(household: @household, user: @alice, kind: "week", week_start: Date.new(2026, 10, 19), amount: 17.5)
  end

  # ---- Individual data ------------------------------------------------------

  test "a superadmin reads a member's logs, preferences, shares and gap entries; the reading is logged" do
    admin = sign_in_team!(role: "superadmin")
    add_individual_data!

    get "/admin/users/#{@alice.id}"
    assert_select "a[href=?]", "/admin/users/#{@alice.id}/individual_data", text: "Données individuelles"
    get "/admin/households/#{@household.id}"
    assert_select "a[href=?]", "/admin/users/#{@alice.id}/individual_data", text: "Consulter"
    assert_equal 0, AdminAction.where(action: "user.individual_data_viewed").count, "a link alone logs nothing"

    assert_difference "AdminAction.where(action: 'user.individual_data_viewed').count", 1 do
      get "/admin/users/#{@alice.id}/individual_data"
    end
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "[data-test=logs]", text: /Rendez-vous pédiatre.*37/m
    assert_select "[data-test=preferences]", text: /Je n'aime pas/
    assert_select "[data-test=shares]", text: /71 %.*64 %/m
    assert_select "[data-test=gap-entries]", text: /17\.5/
    assert_text "Cette consultation est inscrite au journal."

    entry = last_entry
    assert_equal admin, entry.admin_user
    assert_equal [ "User", @alice.id ], [ entry.record_type, entry.record_id ]
    assert_equal @household.id, entry.detail["household_id"]
    assert_equal %w[logs preferences shares gap_entries], entry.detail["sections"]

    get "/admin/admin_actions"
    assert_text "Données individuelles consultées"
  end

  test "the service itself refuses a plain admin, and logs before handing anything" do
    plain = create_admin(email: "plain@cinquante.test")
    assert_raises(BackOffice::IndividualData::Refused) { BackOffice::IndividualData.open(plain, @alice) }
    assert_equal 0, AdminAction.count
  end

  test "the privacy draft says that authorised team members may read individual data, each access logged" do
    get privacy_path
    assert_text "Seuls les membres de l'équipe autorisés peuvent consulter les données individuelles d'une personne"
    assert_text "chaque consultation est journalisée"
  end

  # ---- Team management --------------------------------------------------------

  test "a plain admin sees no team page and cannot run a team action" do
    sign_in_team!
    other = create_admin(email: "other@cinquante.test")

    get "/admin"
    assert_select "a[href='/admin/admin_users']", count: 0
    [ "/admin/admin_users", "/admin/admin_users/#{other.id}", "/admin/admin_users/new" ].each do |path|
      get path
      assert_response :redirect, path
      assert_match(/pas autorisé/, flash[:error], path)
    end
    assert_no_difference "AdminUser.count" do
      post "/admin/admin_users", params: { admin_user: { email: "new@cinquante.test", role: "superadmin" } }
    end
    post "/admin/admin_users/#{other.id}/change_role", params: { role: "superadmin" }
    post "/admin/admin_users/#{other.id}/deactivate"
    post "/admin/admin_users/#{other.id}/reset_two_factor"
    other.reload
    assert other.admin?
    assert_not other.deactivated?
    assert other.two_factor_enrolled?
    assert_equal 0, AdminAction.where(action: %w[admin.created admin.role_changed admin.deactivated admin.two_factor_reset]).count
  end

  test "a superadmin creates an account: password and one-time link shown once, logged without them" do
    sign_in_team!(role: "superadmin")
    get "/admin/admin_users/new"
    assert_response :success

    assert_difference "AdminUser.count", 1 do
      post "/admin/admin_users", params: { admin_user: { email: " New@Cinquante.test ", role: "admin" } }
    end
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    created = AdminUser.find_by!(email: "new@cinquante.test")
    assert created.admin?
    assert_not created.two_factor_enrolled?

    password = css_select("[data-test=password]").text
    link = css_select("[data-test=enrolment-link]").text
    assert created.valid_password?(password)
    token = link[%r{/admin/two_factor/link/(.+)\z}, 1]
    assert_equal created, AdminUser.find_by_token_for(:enrolment, token)

    entry = last_entry
    assert_equal "admin.created", entry.action
    assert_equal [ "AdminUser", created.id ], [ entry.record_type, entry.record_id ]
    assert_equal "admin", entry.detail["role"]
    assert_not_includes entry.detail.to_json, password
    assert_not_includes entry.detail.to_json, token

    # The new person enrols through the link with that password.
    delete destroy_admin_user_session_path
    open_enrolment_link(created, token: token)
    sign_in_admin(created, otp: "", password: password)
    get "/admin/two_factor"
    post "/admin/two_factor", params: { code: otp_code(created) }
    assert created.reload.two_factor_enrolled?
  end

  test "a superadmin changes a role, deactivates an account and resets a second factor; each is logged" do
    sign_in_team!(role: "superadmin")
    other = create_admin(email: "other@cinquante.test")

    post "/admin/admin_users/#{other.id}/change_role", params: { role: "superadmin" }
    assert other.reload.superadmin?
    assert_equal [ "admin.role_changed", { "from" => "admin", "to" => "superadmin" } ], [ last_entry.action, last_entry.detail ]

    post "/admin/admin_users/#{other.id}/reset_two_factor"
    assert_response :success
    assert_not other.reload.two_factor_enrolled?
    assert_select "[data-test=enrolment-link]", text: %r{/admin/two_factor/link/}
    assert_select "[data-test=password]", count: 0
    assert_equal "admin.two_factor_reset", last_entry.action

    post "/admin/admin_users/#{other.id}/deactivate"
    assert other.reload.deactivated?
    assert_equal "admin.deactivated", last_entry.action
    assert_equal other.id, last_entry.record_id
  end

  test "a superadmin cannot demote or deactivate themselves (the team keeps a superadmin)" do
    admin = sign_in_team!(role: "superadmin")
    assert_no_difference "AdminAction.count" do
      post "/admin/admin_users/#{admin.id}/change_role", params: { role: "admin" }
      post "/admin/admin_users/#{admin.id}/deactivate"
    end
    assert admin.reload.superadmin?
    assert_not admin.deactivated?
  end

  test "a superadmin still does what an admin does" do
    sign_in_team!(role: "superadmin")
    @household.update!(state: "blocked", blocked_at: 1.day.ago)
    post "/admin/households/#{@household.id}/unblock"
    assert_predicate @household.reload, :active?
    [ "/admin", "/admin/users", "/admin/households", "/admin/invitations", "/admin/admin_actions", "/admin/admin_users" ].each do |path|
      get path
      assert_response :success, path
    end
  end
end
