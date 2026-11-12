require "test_helper"

# One-click unsubscribe (D9), the F4 settings, the feed (H).
class NotificationsIntegrationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:alice)
    @household = households(:smith_home)
  end

  def token(user = @alice, type = "alert") = Notifications::Unsubscribe.token_for(user, type)

  def create_notification(user: @alice, kind: "alert_no_logs", key: SecureRandom.hex(4), read: false, deliver_at: 1.hour.ago, **attrs)
    entry = Notifications::Catalogue.fetch(kind)
    facts = { "subject" => { "user_id" => @alice.id, "first_name" => "Alice" }, "week_start" => "2026-02-01", "week_end" => "2026-02-07",
              "week_number" => 5, "counts" => [], "recent" => [] }
    Notification.create!({ user: user, household: @household, kind: kind, event_type: entry.event_type, cap_class: entry.cap, dedup_key: key,
                           facts: facts, deliver_at: deliver_at, read_at: (Time.current if read) }.merge(attrs))
  end

  # ---- unsubscribe ------------------------------------------------------------

  test "the link in the email switches the type off, without signing in" do
    get unsubscribe_path(token)

    assert_response :success
    assert_select "h1", "C'est fait."
    assert_not NotificationPreference.enabled?(@alice, "alert")
    assert NotificationPreference.enabled?(@alice, "weekly_report")
  end

  test "the mail client's POST (List-Unsubscribe=One-Click) works with no session, no CSRF token and any user agent" do
    with_forgery_protection do
      post unsubscribe_path(token), params: { "List-Unsubscribe" => "One-Click" }, headers: { "User-Agent" => "Mail-Client/1.0" }
    end

    assert_response :ok
    assert_not NotificationPreference.enabled?(@alice, "alert")
  end

  test "undo switches it back on" do
    get unsubscribe_path(token)
    assert_select "form[action=?] button", resubscribe_path(token), text: "Réactiver"

    post resubscribe_path(token)

    assert_response :success
    assert_select "h1", "Réactivé."
    assert NotificationPreference.enabled?(@alice, "alert")
  end

  test "a tampered token changes nothing and says the same thing for every failure" do
    good = token
    payload, signature = good.split("--")
    forged = "#{Base64.urlsafe_encode64({ _rails: { data: [ users(:bob).id, "alert" ], pur: "notification_unsubscribe" } }.to_json)}--#{signature}"

    [ forged, "#{payload}--#{signature.reverse}", "nonsense" ].each do |bad|
      get unsubscribe_path(bad)
      assert_response :not_found
      assert_select "h1", "Ce lien n'est plus valide."

      post unsubscribe_path(bad)
      assert_response :not_found

      post resubscribe_path(bad)
      assert_response :not_found
    end

    assert_equal NotificationPreference::DEFAULTS, NotificationPreference.settings_for(@alice)
    assert_equal NotificationPreference::DEFAULTS, NotificationPreference.settings_for(users(:bob))
    assert_equal 0, NotificationPreference.count
  end

  test "the unsubscribe link of a real email works and only touches that type" do
    @household.household_members.find_by!(user: users(:bob))
    notification = create_notification(user: users(:bob), kind: "weekly_report", facts: report_facts)
    mail = NotificationMailer.notify(notification)
    url = mail.header["List-Unsubscribe"].to_s[/<(.+)>/, 1]

    get URI(url).path

    assert_response :success
    assert_not NotificationPreference.enabled?(users(:bob), "weekly_report")
    assert NotificationPreference.enabled?(users(:bob), "alert")
    assert NotificationPreference.enabled?(@alice, "weekly_report")
  end

  # ---- F4 -----------------------------------------------------------------------

  test "the account screen shows the five switches, all on by default" do
    sign_in @alice
    get account_path

    assert_response :success
    assert_select "h2", "Notifications"
    NotificationPreference::EVENT_TYPES.each do |type|
      assert_select "input[type=checkbox][role=switch][name=?][checked]", "preferences[#{type}]"
    end
    assert_select "span", "Bilan du dimanche soir"
    assert_select "span", "Alerte : semaine sans saisie"
    assert_select "a[href=?]", notifications_path
  end

  test "saving the switches stores one setting per event type" do
    sign_in @alice

    patch account_notifications_path, params: { preferences: { weekly_report: "0", task_assigned: "1", alert: "0", unknown: "0" } }

    assert_redirected_to account_path
    settings = NotificationPreference.settings_for(@alice)
    assert_equal false, settings["weekly_report"]
    assert_equal false, settings["alert"]
    assert_equal true, settings["task_assigned"]
    assert_equal true, settings["monday_split"]
    assert_not NotificationPreference.exists?(event_type: "unknown")

    get account_path
    assert_select "input[name=?][checked]", "preferences[weekly_report]", count: 0
    assert_select "input[name=?][checked]", "preferences[monday_split]"
  end

  test "settings belong to the person signed in" do
    sign_in @alice
    patch account_notifications_path, params: { preferences: { weekly_report: "0" } }

    assert NotificationPreference.enabled?(users(:bob), "weekly_report")
  end

  test "the settings need a session" do
    patch account_notifications_path, params: { preferences: { weekly_report: "0" } }

    assert_redirected_to new_user_session_path
  end

  # ---- the feed -------------------------------------------------------------------

  test "the feed lists the notifications, unread first marked, and opening one marks it read" do
    unread = create_notification(key: "a", deliver_at: 1.hour.ago)
    create_notification(key: "b", read: true, deliver_at: 2.hours.ago, kind: "alert_unblocked", facts: { "week_number" => 5, "balanced" => true, "level" => 2, "next_level" => 3 })
    create_notification(key: "other person", user: users(:bob))
    sign_in @alice

    get notifications_path

    assert_response :success
    assert_select ".list-row", count: 2
    assert_select ".pill", text: "Non lue", count: 1
    assert_select "a[href=?]", notification_path(unread), text: /Alice n'a enregistré aucune tâche cette semaine|vous n'avez enregistré/i

    get notification_path(unread)

    assert_redirected_to dashboard_path
    assert unread.reload.read?
    assert_equal 0, Notification.unread_count_for(@alice)
  end

  test "an alert with a switched-off type is not in the feed, one held back by the cap is" do
    create_notification(key: "off", suppressed_reason: "preference")
    create_notification(key: "capped", suppressed_reason: "cap")
    sign_in @alice

    get notifications_path

    assert_select ".list-row", count: 1
    assert_select "p", text: /déjà parti cette semaine/
  end

  test "an event that is not due yet is not in the feed" do
    create_notification(deliver_at: 3.hours.from_now)
    sign_in @alice

    get notifications_path

    assert_select ".list-row", count: 0
    assert_select "p", "Rien pour l'instant."
  end

  test "mark all as read" do
    2.times { |i| create_notification(key: "n#{i}") }
    sign_in @alice

    patch read_all_notifications_path

    assert_redirected_to notifications_path
    assert_equal 0, Notification.unread_count_for(@alice)
  end

  test "nobody reads another person's notification" do
    other = create_notification(user: users(:bob))
    sign_in @alice

    get notification_path(other)

    assert_response :not_found
    assert_nil other.reload.read_at
  end

  test "the header bell shows the unread count" do
    2.times { |i| create_notification(key: "n#{i}") }
    sign_in @alice

    get dashboard_path

    assert_select "header a[href=?][aria-label=?]", notifications_path, "Notifications, 2 non lues"
  end

  test "the feed needs a session" do
    get notifications_path
    assert_redirected_to new_user_session_path
  end

  private

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def report_facts
    { "week_number" => 5, "outcome" => "balanced", "zone_min" => 40, "zone_max" => 60, "members" => [], "history" => [],
      "level" => 1, "ultimate" => false, "blocked" => false, "weeks_to_next_level" => 2, "previous_unbalanced" => 0 }
  end
end
