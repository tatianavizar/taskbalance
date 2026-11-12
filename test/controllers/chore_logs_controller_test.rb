require "test_helper"

# D6, D7, D10 (logging), E6 (journal), E12 (correct), E16 (delete).
class ChoreLogsControllerTest < ActionDispatch::IntegrationTest
  include FinalWeekHelper

  setup do
    travel_to(Time.find_zone("Europe/Paris").local(2026, 11, 8, 18, 40))
    @alice = users(:alice)
    @bob = users(:bob)
    @household = households(:smith_home)
    @chore = chores(:smith_cooking)
    sign_in @alice
  end

  teardown { travel_back }

  def params_for(overrides = {})
    { log_entry: { chore_id: @chore.id, mental_load: "1", execution_load: "1", time_spent: "30",
                   idempotency_key: SecureRandom.uuid }.merge(overrides) }
  end

  def log_for(user, **attributes)
    ChoreLog.create!({ user: user, household: @household, chore: @chore, mental_load: true, execution_load: false,
                       time_spent: 20, completed_at: Time.current }.merge(attributes))
  end

  # --- D6, D7 ---------------------------------------------------------------

  test "new shows the form, prefilled from the chore, with a key and eight days to choose" do
    get new_chore_log_path(chore_id: @chore.id)

    assert_response :success
    assert_select "input[name=?][value=?]", "log_entry[time_spent]", @chore.effective_time_required.to_s
    assert_select "input[name=?]:not([value=''])", "log_entry[idempotency_key]"
    assert_select "select[name=?] option", "log_entry[day]", 8
    assert_select "button[aria-label=?]", "Plus 5 minutes"
  end

  test "create logs for the signed-in person and goes back to the home" do
    assert_difference -> { @alice.chore_logs.count }, 1 do
      post chore_logs_path, params: params_for
    end

    assert_redirected_to dashboard_path
    log = @alice.chore_logs.order(:id).last
    assert_equal @household, log.household
    assert_equal 30, log.time_spent
    assert_equal "Enregistré : #{@chore.effective_name}.", flash[:notice], "a success message names no one"
  end

  test "the author is current_user, whoever the request names" do
    assert_no_difference -> { @bob.chore_logs.count } do
      post chore_logs_path, params: params_for(user_id: @bob.id)
    end
    assert_equal 1, @alice.chore_logs.count
  end

  test "a double tap makes one log" do
    key = SecureRandom.uuid
    assert_difference -> { ChoreLog.count }, 1 do
      2.times { post chore_logs_path, params: params_for(idempotency_key: key) }
    end
    assert_redirected_to dashboard_path
  end

  test "up to 7 days back, refused beyond" do
    assert_difference -> { ChoreLog.count }, 1 do
      post chore_logs_path, params: params_for(day: "2026-11-01")
    end
    assert_equal Date.new(2026, 11, 1), @alice.chore_logs.order(:id).last.completed_on

    assert_no_difference -> { ChoreLog.count } do
      post chore_logs_path, params: params_for(day: "2026-10-31")
    end
    assert_response :unprocessable_entity
    assert_field_error "Pas plus de 7 jours en arrière."
  end

  test "errors are shown inline and the key is kept for the retry (D7)" do
    key = SecureRandom.uuid
    post chore_logs_path, params: params_for(mental_load: "0", execution_load: "0", time_spent: "", idempotency_key: key)

    assert_response :unprocessable_entity
    assert_select ".alert-box", /2 champs à corriger/
    assert_field_error "Cochez au moins une charge. Les deux sont possibles."
    assert_field_error "Indiquez combien de temps ça a pris, même approximativement."
    assert_select "input[name=?][value=?]", "log_entry[idempotency_key]", key
  end

  test "a task outside the split is typed by hand and labelled in the journal" do
    post chore_logs_path, params: { log_entry: { chore_id: "", custom_name: "Ranger le garage", category: "maintenance",
                                                 mental_load: "0", execution_load: "1", time_spent: "90" } }
    assert_redirected_to dashboard_path

    get chore_logs_path
    assert_text "Ranger le garage"
    assert_text "hors répartition"
  end

  test "someone without a household cannot log" do
    sign_in users(:dana)
    get new_chore_log_path
    assert_redirected_to dashboard_path
  end

  # --- E6 -------------------------------------------------------------------

  test "the journal lists my logs only, grouped by week and day, detached ones included" do
    mine = log_for(@alice, chore_name: "Cook a meal")
    log_for(@bob, chore_name: "Pas à moi")
    detached = ChoreLog.create!(user: @alice, household: nil, chore: nil, chore_name: "Tâche d'un ancien foyer",
                                category: "cleaning", mental_load: true, execution_load: true, time_spent: 40,
                                completed_at: Time.current - 2.days)

    get chore_logs_path

    assert_response :success
    assert_text "Semaine 45"
    assert_text mine.chore_name
    assert_text detached.chore_name
    assert_text "plus rattaché à un foyer"
    assert_not response.body.include?("Pas à moi")
  end

  test "a log whose chore and household are deleted stays in the journal under its snapshot" do
    log = log_for(@alice)
    @chore.destroy!
    @household.update!(name: "Renommé")
    ChoreLog.where(id: log.id).update_all(household_id: nil)

    get chore_logs_path
    assert_text "Cook a meal"
    assert_select "a[href=?]", edit_chore_log_path(log)
  end

  test "the journal needs a signed-in person" do
    sign_out @alice
    get chore_logs_path
    assert_redirected_to new_user_session_path
  end

  # --- E12 ------------------------------------------------------------------

  test "the author corrects loads, duration and day" do
    log = log_for(@alice)

    get edit_chore_log_path(log)
    assert_response :success

    patch chore_log_path(log), params: params_for(mental_load: "1", execution_load: "1", time_spent: "45", day: "2026-11-06")

    assert_redirected_to chore_logs_path
    log.reload
    assert_equal [ true, true, 45, Date.new(2026, 11, 6) ], [ log.mental_load, log.execution_load, log.time_spent, log.completed_on ]
    assert_equal @alice, log.user, "the author does not change"
  end

  test "someone else cannot see the edit screen, correct or delete" do
    log = log_for(@bob)

    get edit_chore_log_path(log)
    assert_redirected_to chore_logs_path
    patch chore_log_path(log), params: params_for(time_spent: "99")
    assert_redirected_to chore_logs_path
    get delete_chore_log_path(log)
    assert_redirected_to chore_logs_path
    assert_no_difference -> { ChoreLog.count } do
      delete chore_log_path(log)
    end
    assert_equal 20, log.reload.time_spent
  end

  test "a log of a closed week keeps its day and says it only changes the journal" do
    last_week = Week.containing(Date.new(2026, 11, 1), "Europe/Paris")
    log = log_for(@alice, completed_at: last_week.start_at + 2.days)
    close_week!(@household, last_week)

    get edit_chore_log_path(log)
    assert_text "ne change que votre journal"
    assert_select "select[name=?]", "log_entry[day]", 0

    patch chore_log_path(log), params: params_for(time_spent: "60", day: "2026-11-08")
    assert_equal 60, log.reload.time_spent
    assert_equal last_week.start_at.to_date + 2, log.completed_on, "the day cannot move"
  end

  # --- E16 ------------------------------------------------------------------

  test "the confirmation comes first and deleting removes that log only" do
    log = log_for(@alice)
    other = log_for(@alice, time_spent: 5)

    get delete_chore_log_path(log)
    assert_response :success
    assert_text "Cette action ne peut pas être annulée."
    assert_select "form[action=?] button", chore_log_path(log), text: "Supprimer"
    assert ChoreLog.exists?(log.id), "nothing is deleted by looking at the confirmation"

    assert_difference -> { ChoreLog.count }, -1 do
      delete chore_log_path(log)
    end
    assert_redirected_to chore_logs_path
    assert_not ChoreLog.exists?(log.id)
    assert ChoreLog.exists?(other.id)
    assert_equal "Enregistrement supprimé.", flash[:notice]
  end

  test "deleting a log reopens its occurrence" do
    occurrence = ChoreOccurrence.create!(household: @household, chore: @chore, week_start: Date.new(2026, 11, 2), slot: 50, due_on: Date.new(2026, 11, 8))
    log = log_for(@alice, occurrence: occurrence)
    assert_equal [ @alice.id ], occurrence.reload.done_by_ids

    delete chore_log_path(log)

    assert_empty occurrence.reload.done_by_ids
  end
end
