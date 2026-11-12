require "test_helper"

# D1, D2, D8, D12: the home on the real figures of the week, live.
class HomeTest < ActionDispatch::IntegrationTest
  include WeeklyEngineHelpers
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to(paris(2026, 11, 4, 18, 32))
    @household, (@virginie, @karim) = build_household("Virginie", "Karim")
    sign_in @virginie
  end

  teardown { travel_back }

  def log_many(user, count, **options)
    log!(@household, user, at: paris(2026, 11, 3, 10), count: count, **options)
  end

  def stats = WeeklyStats.new(@household.reload, @household.current_week)

  test "D1: nothing is measured on a week without logs" do
    get dashboard_path

    assert_response :success
    assert_text "Semaine 45"
    assert_text "2 nov – 8 nov"
    assert_text "mis à jour à 18:32"
    assert_text "Rien n'est encore mesuré."
    assert_text "Le premier bilan arrive dimanche 8 novembre au soir."
    assert_select "section.card b", text: "—", count: 4 # two dimensions, two people
  end

  test "D2: the headline names who carries more, in the figures WeeklyStats gives" do
    log_many(@virginie, 5, mental: true, execution: false)
    log_many(@karim, 2, mental: true, execution: false)
    log_many(@virginie, 3, mental: false, execution: true)
    log_many(@karim, 3, mental: false, execution: true)

    get dashboard_path

    mental = stats.member_for(@virginie).mental_share
    assert_equal 71, mental
    assert_text "Virginie porte 71 % de la charge mentale."
    assert_text "Au-dessus de 60 %"
    assert_text "5 tâches sur 7"
    assert_text "3 tâches sur 6"
    assert_select "section.card", text: /Charge mentale/ do
      assert_select "b", text: "71 %"
      assert_select "b", text: "29 %"
      assert_select "span", text: "hors zone"
    end
    # Never softened: no « points », only percentages.
    assert_not response.body.include?("points")
  end

  test "the home shows the stored counts of every member as WeeklyStats computes them" do
    log_many(@virginie, 4)
    log_many(@karim, 4)

    get dashboard_path

    stats.members.each do |member|
      assert_equal 50, member.mental_share
      assert_equal 50, member.execution_share
    end
    assert_text "La semaine est équilibrée pour l'instant."
    assert_text "zone de 40 à 60 %"
    assert_text "4 tâches sur 8"
  end

  test "the viewer sees their own share first, the others after" do
    log_many(@virginie, 1)
    log_many(@karim, 3)
    sign_in @karim

    get dashboard_path
    assert_text "Karim porte"
    assert_text "75 %"
  end

  test "the level and its progress come from the household" do
    @household.update_columns(level: 1, balanced_weeks_count: 1)

    get dashboard_path

    assert_text "Niveau 1"
    assert_text "1 semaine équilibrée sur 3 pour le niveau 2"
  end

  test "the ultimate level has no next level" do
    @household.update_columns(level: Progression::ULTIMATE, balanced_weeks_count: 15)

    get dashboard_path

    assert_text "Niveau ultime"
    assert_not response.body.include?("pour le niveau 6")
  end

  test "a provisional report is labelled, and a final one" do
    log_many(@virginie, 1)
    week = @household.current_week
    row = @household.household_weeks.create!(WeeklyStats.new(@household, week).to_snapshot.merge(
      status: "provisional", computed_at: Time.current))

    get dashboard_path
    assert_select ".pill", "Provisoire"
    assert_text "jusqu'à lundi 3:00 compte encore"

    row.update!(status: "final", finalized_at: Time.current)
    get dashboard_path
    assert_select ".pill", "Définitif"
  end

  test "D12: someone who arrived this week is told it does not count, with their planned tasks" do
    late = join(@household, "Louise", at: paris(2026, 11, 3, 9))
    sign_in late

    get dashboard_path

    assert_text "Votre arrivée a eu lieu en cours de semaine"
    assert_text "La semaine 46 sera la première à compter, close le lundi 16 novembre"
  end

  test "the home carries the slot for the weekly split card" do
    WeekPlan.propose!(household: @household, by: @virginie, week: @household.current_week, kind: :weekly)
    get dashboard_path
    assert_response :success
  end

  test "the page listens to the household's stream and refreshes by morphing" do
    get dashboard_path

    assert_select "turbo-cable-stream-source"
    assert_select "meta[name=turbo-refresh-method][content=morph]"
  end

  # --- live update ------------------------------------------------------------

  test "a log, a correction and a deletion each refresh the household's home" do
    stream = Household.home_stream(@household)

    log = nil
    assert_turbo_stream_broadcasts(stream, count: 1) do
      log = ChoreLog.create!(user: @virginie, household: @household, chore_name: "Ménage", category: "cleaning",
                             mental_load: true, execution_load: false, time_spent: 10, completed_at: Time.current)
    end
    # The test adapter keeps what was published: the count is cumulative.
    assert_turbo_stream_broadcasts(stream, count: 2) { log.update!(time_spent: 15) }
    assert_turbo_stream_broadcasts(stream, count: 3) { log.destroy! }
  end

  test "logging through the form broadcasts to the household" do
    chore = @household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @virginie.id ])

    assert_turbo_stream_broadcasts(Household.home_stream(@household), count: 1) do
      post chore_logs_path, params: { log_entry: { chore_id: chore.id, mental_load: "1", execution_load: "0",
                                                   time_spent: "20", idempotency_key: "k" } }
    end
  end

  test "another household's stream is not touched" do
    assert_no_turbo_stream_broadcasts(Household.home_stream(households(:jones_home))) do
      log_many(@virginie, 1)
    end
  end
end
