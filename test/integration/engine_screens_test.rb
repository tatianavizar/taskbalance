require "test_helper"

# Lot 5b: the screens of the weekly engine. The Bilan tab (E1, E2, E7, E10,
# E14), the levels (E8, E9, E13), the alerts of the home and of the Bilan
# (E3, E4, E5, D13, E15), the absence question (E11), the pauses (F6, F8,
# F10) and the notification links. Figures come from WeeklyStats for the
# current week and from the stored HouseholdWeek for the others.
class EngineScreensTest < ActionDispatch::IntegrationTest
  include WeeklyEngineHelpers
  include FinalWeekHelper

  JOINED = -> { ActiveSupport::TimeZone["Europe/Paris"].local(2026, 10, 4, 9) }

  teardown { travel_back }

  # The text of the page with the markup gone and the white space squeezed: a
  # sentence the view wraps over several lines is still one sentence.
  def assert_page_text(text)
    plain = CGI.unescapeHTML(response.body.gsub(/<[^>]+>/, " ")).squish
    assert_includes plain, text
  end

  def week(n) = Week.containing(Date.new(2026, 10, 5) + (7 * n), PARIS)
  def mid(week) = week.start_at + 2.days + 10.hours # Wednesday 10:00 local
  def final_at(week) = HouseholdWeek.final_at(week)

  def couple = build_household("Virginie", "Karim", joined_at: JOINED.call)

  # Virginie logs the two empty weeks 1 and 2, Karim logs nothing: first
  # empty week at the closing of week 1, the absence question at week 2.
  def two_empty_weeks_for_karim(household, virginie, karim)
    log_balanced_week!(household, [ virginie, karim ], week(0))
    log!(household, virginie, at: mid(week(1)))
    log!(household, virginie, at: mid(week(2)))
  end

  def stored_week!(household, week, outcome, neutral_reason: nil)
    household.household_weeks.create!(week_start: week.monday, time_zone: PARIS, status: "final", outcome: outcome,
                                      neutral_reason: neutral_reason, fair_share: 50, computed_at: Time.current,
                                      finalized_at: Time.current)
  end

  # ---- E1: the current week, provisional ----------------------------------------------

  test "E1: the week in progress is provisional, read live, names who carries more and says what to change on Monday" do
    travel_to(paris(2026, 11, 4, 18, 32))
    household, (virginie, karim) = build_household("Virginie", "Karim")
    at = paris(2026, 11, 3, 10)
    log!(household, virginie, at: at, count: 5, mental: true, execution: false)
    log!(household, karim, at: at, count: 2, mental: true, execution: false)
    log!(household, virginie, at: at, count: 3, mental: false, execution: true)
    log!(household, karim, at: at, count: 3, mental: false, execution: true)
    sign_in virginie

    get report_path

    assert_response :success
    assert_select "h1", "Bilan"
    assert_text "Semaine 45"
    assert_text "Provisoire · définitif lundi 9 nov à 3:00"
    assert_text "Non équilibrée pour l'instant"
    assert_text "Virginie porte 71 % de la charge mentale"
    assert_text "Il aurait suffi de confier 1 des 5 tâches mentales de Virginie à Karim."
    assert_select "#report-lesson" do
      assert_select "b", "À retenir pour la répartition de lundi"
      assert_select "p", text: /L'exécution est dans la zone \(Virginie : 50 %\), pas la charge mentale \(Virginie : 71 %\)/
      assert_select "b", text: "Lundi : confier à Karim au moins 1 tâche à charge mentale de Virginie."
    end
    assert_select "section.card b", text: "71 %"
    assert_not response.body.include?("points"), "percentages only"
    assert_select "nav[aria-label=?] a[aria-current=page]", "Période du bilan", text: "Semaine"
  end

  test "E1: a week where execution is the charge out of the zone gets the matching card" do
    travel_to(paris(2026, 11, 4, 18, 32))
    household, (virginie, karim) = build_household("Virginie", "Karim")
    at = paris(2026, 11, 3, 10)
    log!(household, virginie, at: at, count: 3, mental: true, execution: false)
    log!(household, karim, at: at, count: 3, mental: true, execution: false)
    log!(household, virginie, at: at, count: 7, mental: false, execution: true)
    log!(household, karim, at: at, count: 2, mental: false, execution: true)
    sign_in karim

    get report_path

    assert_text "Virginie porte 78 % de l'exécution"
    assert_select "#report-lesson" do
      assert_select "b", text: "Lundi : confier à Karim au moins 2 tâches à faire de Virginie."
      assert_select "p", text: /planifier ne suffit pas/
    end
  end

  # ---- E14: a final week, never rewritten --------------------------------------------------

  test "E14 and E8: a final balanced week names no one, is read from its snapshot and moves the level" do
    household, (virginie, karim) = couple
    log_balanced_week!(household, [ virginie, karim ], week(0))
    run_engine(household, final_at(week(0)))
    travel_to(paris(2026, 10, 12, 10))
    sign_in virginie

    get report_path(semaine: week(0).monday.iso8601)

    assert_response :success
    assert_text "Semaine 41"
    assert_text "Définitif · clos le lundi 12 oct à 3:00"
    assert_select "#report-outcome h2", "Équilibrée"
    assert_select "#report-outcome", text: /Virginie|Karim/, count: 0 # success names no one
    assert_text "Chaque membre entre 40 et 60 %, sur les deux charges."
    assert_text "1 tâche sur 2"
    assert_select "#report-level-#{household.level_changes.reached.first.id}", text: /Niveau 1 atteint à ce bilan/

    # A log back-dated into the closed week never changes its report.
    log!(household, virginie, at: mid(week(0)) + 1.hour, count: 4)
    get report_path(semaine: week(0).monday.iso8601)
    assert_text "1 tâche sur 2"
    assert_select "#report-outcome h2", "Équilibrée"

    # E8 on the home, then the ladder.
    get dashboard_path
    assert_select "#alert-level h2", "Niveau 1 atteint"
    assert_text "1 semaine équilibrée au total."
    get levels_path
    assert_response :success
    assert_select "#level-now h2", "Niveau 1"
    assert_select "#level-ladder li[aria-current=step]", text: /Niveau 1/
    assert_text "Prochain : niveau 2, dans 2 semaines équilibrées."
    assert_text "Les semaines non équilibrées ne font pas reculer."
  end

  test "the week asked for stays between the household's first week and the current one" do
    household, (virginie, _) = couple
    travel_to(paris(2026, 10, 14, 10))
    sign_in virginie

    get report_path(semaine: "2020-01-06")
    assert_text household.week_containing(household.created_at).label
    get report_path(semaine: "2031-01-06")
    assert_text "Semaine 42"
    get report_path(semaine: "n'importe quoi")
    assert_response :success
    assert_text "Semaine 42"
  end

  test "E1 with three members: the fair share is 33 %, the others are named together" do
    travel_to(paris(2026, 11, 4, 18, 32))
    household, (virginie, karim) = build_household("Virginie", "Karim")
    karine = join(household, "Karine", at: paris(2026, 9, 1, 9))
    at = paris(2026, 11, 3, 10)
    log!(household, virginie, at: at, count: 6, mental: true, execution: false)
    log!(household, karim, at: at, count: 2, mental: true, execution: false)
    log!(household, karine, at: at, count: 2, mental: true, execution: false)
    [ virginie, karim, karine ].each { |user| log!(household, user, at: at, count: 2, mental: false, execution: true) }
    sign_in karine

    get report_path

    assert_response :success
    assert_text "Virginie porte 60 % de la charge mentale"
    assert_select "#report-lesson b", text: /Lundi : confier aux autres membres au moins 2 tâches à charge mentale de Virginie\./
    assert_select "section.card", text: /Charge mentale/ do
      assert_select "b", text: "20 %"
    end
  end

  # ---- E7, E10: neutral weeks ----------------------------------------------------------------

  test "E7: a week without any mental load is neutral and says why" do
    household, (virginie, karim) = couple
    log!(household, virginie, at: mid(week(0)), mental: false)
    log!(household, karim, at: mid(week(0)), mental: false)
    run_engine(household, final_at(week(0)))
    travel_to(paris(2026, 10, 13, 10))
    sign_in karim

    get report_path(semaine: week(0).monday.iso8601)

    assert_text "Semaine neutre : aucune charge mentale enregistrée"
    assert_text "personne n'a enregistré de tâche mentale"
    assert_text "ne compte ni pour ni contre le foyer"
    assert_text "Penser, prévoir, décider : ça s'enregistre aussi."
    assert_select "#report-outcome h2", text: /Non équilibrée/, count: 0
  end

  test "E10: a paused week is neutral, shows the dates and never the private reason" do
    household, (virginie, karim) = couple
    travel_to(paris(2026, 10, 6, 9))
    MemberPause.declare!(member: membership(household, karim), declared_by: karim, starts_on: Date.new(2026, 10, 5),
                         ends_on: Date.new(2026, 10, 18), reason: "Vacances en famille")
    log!(household, virginie, at: mid(week(0)), count: 2)
    run_engine(household, final_at(week(0)))
    travel_to(paris(2026, 10, 13, 10))
    sign_in virginie

    get report_path(semaine: week(0).monday.iso8601)

    assert_text "Semaine neutre : un seul membre actif"
    assert_select "#report-pauses" do
      assert_select "b", "Karim"
      assert_text "Du 5 oct au 18 oct"
    end
    assert_text "La raison d'une pause n'est visible que par la personne concernée."
    assert_not response.body.include?("Vacances en famille")
  end

  # ---- E10 / D3: a corrected week -------------------------------------------------------------

  test "D3: a pause declared after the closing lays « Neutre · pause déclarée le … » over the stored week" do
    household, (virginie, karim) = couple
    two_empty_weeks_for_karim(household, virginie, karim)
    run_engine(household, paris(2026, 10, 28, 21))
    assert_predicate household, :blocked?
    travel_to(paris(2026, 10, 29, 9))
    MemberPause.declare!(member: membership(household, karim), declared_by: virginie,
                         starts_on: week(1).monday, ends_on: week(2).sunday)
    travel_to(paris(2026, 10, 29, 12))
    sign_in karim

    get report_path(semaine: week(2).monday.iso8601)

    assert_response :success
    assert_select "#report-outcome h2", "Neutre · pause déclarée le 29 oct"
    assert_text "Avant la pause, la semaine était non équilibrée."
    assert_text "Définitif · clos le lundi 26 oct à 3:00"
    assert_equal "unbalanced", household.household_weeks.find_by!(week_start: week(2).monday).outcome, "stored report untouched"

    get report_history_path
    assert_select "#history-week-#{week(2).monday.iso8601} .pill", "Neutre · pause"

    get levels_path
    assert_select "#level-last-change b", text: /Descente annulée : niveau 1/
  end

  # ---- E2: the four weeks ----------------------------------------------------------------------

  test "E2: the last four weeks, each from its report" do
    household, (virginie, karim) = couple
    [ 0, 1, 2 ].each { |n| log_balanced_week!(household, [ virginie, karim ], week(n)) }
    log!(household, virginie, at: mid(week(3)), count: 3)
    log!(household, karim, at: mid(week(3)), count: 1)
    run_engine(household, final_at(week(3)))
    travel_to(paris(2026, 11, 2, 10))
    sign_in virginie

    get report_history_path(jusqu_a: week(3).monday.iso8601)

    assert_response :success
    assert_select "nav[aria-label=?] a[aria-current=page]", "Période du bilan", text: "4 semaines"
    assert_text "Sem. #{week(0).number} – #{week(3).number}"
    assert_select "#history-chart [role=img][aria-label*=?]", "75 %"
    assert_select "#history-week-#{week(3).monday.iso8601}" do
      assert_select ".pill", "Non équilibrée"
      assert_select "span.bg-ink", text: "75 %"
    end
    assert_select "#history-week-#{week(1).monday.iso8601} .pill", "Équilibrée"
    assert_select "#history-table a[href=?]", report_path(semaine: week(3).monday)
  end

  # ---- E9, E13: the ultimate level and its margin --------------------------------------------------

  def ultimate_household(unbalanced:, neutral: 0)
    household, users = couple
    household.update!(level: Progression::ULTIMATE, balanced_weeks_count: 15, ultimate_reached_on: week(0).monday)
    (unbalanced + neutral).times do |i|
      i < unbalanced ? stored_week!(household, week(i), "unbalanced") : stored_week!(household, week(i), "neutral", neutral_reason: "no_mental_logs")
    end
    travel_to(paris(2026, 12, 15, 10))
    sign_in users.first
    household
  end

  test "E9: the margin is the quota minus the unbalanced weeks of the window" do
    {
      0 => "Il vous reste 7 semaines non équilibrées avant de redescendre au niveau 4.",
      3 => "Il vous reste 4 semaines non équilibrées avant de redescendre au niveau 4.",
      6 => "Il vous reste 1 semaine non équilibrée avant de redescendre au niveau 4.",
      7 => "Il ne vous reste aucune semaine : une semaine non équilibrée de plus ramène le foyer au niveau 4."
    }.each do |unbalanced, sentence|
      household = ultimate_household(unbalanced: unbalanced)

      get levels_path

      assert_response :success
      assert_select "#level-now h2", "Niveau ultime"
      assert_select "#level-margin", text: /#{Regexp.escape(sentence)}/
      assert_equal 7 - unbalanced, Progression.ultimate_margin(household)
      assert_text "sur 7 au plus"
      Household.where(id: household.id).destroy_all
    end
  end

  test "E9: neutral weeks are listed apart and never count against the quota" do
    household = ultimate_household(unbalanced: 3, neutral: 2)

    get levels_path

    assert_select "#level-window dl" do
      assert_select "div", text: /Semaines sur la période\s*5/
      assert_select "div", text: /Neutres ou en pause, non comptées\s*2/
      assert_select "div", text: /Non équilibrées\s*3/
    end
    assert_select "#level-margin", text: /Il vous reste 4 semaines non équilibrées/
    assert_equal 4, Progression.ultimate_margin(household)
  end

  test "E13: the ultimate level lost names who carried more in the week that dropped it" do
    household, (virginie, karim) = couple
    household.update!(level: 4, balanced_weeks_count: 15, ultimate_reached_on: week(0).monday)
    7.times { |i| stored_week!(household, week(i), "unbalanced") }
    # Week 7: Virginie carries 16 of the 25 execution logs (64 %).
    at = mid(week(7))
    log!(household, virginie, at: at, count: 5)
    log!(household, karim, at: at, count: 5)
    log!(household, virginie, at: at, count: 11, mental: false)
    log!(household, karim, at: at, count: 4, mental: false)
    record = close_week!(household, week(7))
    travel_to(paris(2026, 11, 24, 10))
    household.level_changes.create!(from_level: 5, to_level: 4, balanced_weeks_count_before: 15, balanced_weeks_count_after: 15,
                                    reason: :ultimate_lost, week_start: week(7).monday, household_week: record)
    sign_in karim

    get dashboard_path
    assert_select "#alert-level h2", "Retour au niveau 4"
    assert_text "Le niveau ultime revient dès que le compte repasse à 7."

    get levels_path
    assert_select "#level-last-change b", "Retour au niveau 4"
    assert_text "Semaine #{week(7).number} non équilibrée : Virginie porte 64 % de l'exécution."
    assert_text "Pour retrouver le niveau ultime :"
    assert_text "sans repartir de zéro"
  end

  # ---- E3 / D13: a first empty week ----------------------------------------------------------------------

  test "E3, D13: the first empty week is told the same way to both, until the person logs again" do
    household, (virginie, karim) = couple
    two_empty_weeks_for_karim(household, virginie, karim)
    run_engine(household, final_at(week(1)))
    assert_equal 1, membership(household, karim).empty_weeks_streak
    travel_to(paris(2026, 10, 19, 10))

    sign_in karim
    get dashboard_path
    assert_select "#alert-first-empty-#{membership(household, karim).id}" do
      assert_select "h2", "Semaine #{week(1).number} close sans aucune tâche de votre part"
      assert_page_text "Du 12 oct au 18 oct. Une absence ?"
      assert_select "a[href^=?]", new_member_pause_path, text: "Déclarer une pause ›"
      assert_text "Vos tâches enregistrées"
    end
    assert_select "#alert-blocked", count: 0

    sign_in virginie
    get dashboard_path
    assert_select "h2", "Karim n'a enregistré aucune tâche en semaine #{week(1).number}"
    assert_text "En semaine #{week(1).number}, Virginie en a enregistré 1."
    assert_select "a", text: /Déclarer une pause/, count: 0 # only after a regression
    get report_path
    assert_select "#alert-first-empty-#{membership(household, karim).id}"

    log!(household, karim, at: paris(2026, 10, 19, 9, 30))
    sign_in karim
    get dashboard_path
    assert_select "[id^=alert-first-empty]", count: 0
  end

  # ---- E11, P5: the absence question -------------------------------------------------------------------------

  def open_inquiry
    household, (virginie, karim) = couple
    two_empty_weeks_for_karim(household, virginie, karim)
    run_engine(household, final_at(week(2)))
    travel_to(paris(2026, 10, 26, 10))
    [ household, virginie, karim, household.absence_inquiries.pending.sole ]
  end

  test "E11: the question is on both homes; each person answers, the person concerned included" do
    household, virginie, karim, inquiry = open_inquiry
    assert_equal paris(2026, 10, 28, 20), inquiry.deadline_at

    sign_in virginie
    get dashboard_path
    assert_select "#alert-inquiry-#{inquiry.id}" do
      assert_text "Absence de Karim ?"
      assert_text "Réponses jusqu'à mercredi 28 oct à 20:00"
      assert_text "pas encore de réponse de votre part"
    end

    get absence_inquiry_path(inquiry)
    assert_response :success
    assert_select "h1", "Absence de Karim ?"
    assert_page_text "Aucune tâche enregistrée par Karim depuis 2 semaines (12 oct – 25 oct). Aucune pause déclarée."
    assert_select "#absence-weeks li", count: 2
    assert_select "#absence-outcome", text: /Sans « Oui » d'ici mercredi 28 oct à 20:00, le foyer redescend au niveau 0 et sa progression est bloquée\./
    assert_select "#absence-answers" do
      assert_select ".pill", text: "Pas encore répondu", count: 2
    end
    assert_select "form[action=?] button", answer_absence_inquiry_path(inquiry), count: 2
    assert_text "Répondre n'est pas obligatoire."

    sign_in karim
    get absence_inquiry_path(inquiry)
    assert_select "h1", "Une absence de votre part ?"
    assert_select "#absence-form form", count: 2
    assert_select "[id^=absence-correct]", count: 0 # nobody answered about them yet
    post answer_absence_inquiry_path(inquiry), params: { answer: "no" }
    assert_redirected_to absence_inquiry_path(inquiry)
    follow_redirect!
    assert_select ".callout", text: /Réponse enregistrée\./
    assert_text "Votre réponse : Non"
    assert_predicate inquiry.reload, :pending?
  end

  test "E11: one « Oui » declares the pause; the person concerned corrects an answer about them and the pause goes" do
    household, virginie, karim, inquiry = open_inquiry
    sign_in virginie

    post answer_absence_inquiry_path(inquiry), params: { answer: "yes" }
    follow_redirect!

    assert_select ".callout", text: /Réponse enregistrée\. Une pause couvre les deux semaines\./
    assert_predicate inquiry.reload, :paused?
    assert_select "#absence-outcome", text: /Une pause est déclarée du 12 oct au 25 oct\. Le foyer garde son niveau\./
    assert_equal [ week(1).monday, week(2).sunday ], membership(household, karim).member_pauses.sole.then { [ _1.starts_on, _1.ends_on ] }

    # The correction is offered to Karim only.
    get absence_inquiry_path(inquiry)
    assert_select "[id^=absence-correct]", count: 0
    sign_in karim
    get absence_inquiry_path(inquiry)
    answer = inquiry.absence_answers.sole
    assert_select "#absence-correct-#{answer.id}" do
      assert_text "Virginie a répondu « Oui » à votre sujet"
    end

    patch correct_absence_inquiry_path(inquiry), params: { answer_id: answer.id, answer: "no" }
    follow_redirect!

    assert_select ".callout", text: /Réponse corrigée\./
    assert_predicate inquiry.reload, :pending?
    assert_empty membership(household, karim).member_pauses
    assert_select "#absence-answers .list-row", text: /Corrigée par Karim \(avant : Oui\)/
  end

  test "E11: a late answer and a correction by someone else are refused with a clear message" do
    household, virginie, karim, inquiry = open_inquiry
    sign_in virginie
    post answer_absence_inquiry_path(inquiry), params: { answer: "no" }
    own = inquiry.absence_answers.sole

    patch correct_absence_inquiry_path(inquiry), params: { answer_id: own.id, answer: "yes" }
    follow_redirect!
    assert_select ".alert-box", text: "Seule la personne concernée peut corriger cette réponse."
    assert_equal "no", own.reload.answer

    post answer_absence_inquiry_path(inquiry), params: { answer: "maybe" }
    follow_redirect!
    assert_select ".alert-box", text: "Cette réponse n'existe pas : choisissez Oui ou Non."

    travel_to(paris(2026, 10, 28, 20, 30))
    post answer_absence_inquiry_path(inquiry), params: { answer: "yes" }
    assert_redirected_to absence_inquiry_path(inquiry)
    follow_redirect!
    assert_select ".alert-box", text: "Le délai est passé : les réponses sont closes."
    assert_select "#absence-form", count: 0
    assert_select "#absence-closed", text: /Les réponses sont closes depuis mercredi 28 oct à 20:00\./
    assert_equal "no", own.reload.answer
    assert_predicate inquiry.reload, :pending?
    assert_equal 0, household.reload.member_pauses.count
  end

  test "E11: an inquiry of another household is a 404, and the notification link lists the open question" do
    _, virginie, _, inquiry = open_inquiry
    other, (outsider, _) = build_household("Camille", "Dominique")
    sign_in outsider

    get absence_inquiry_path(inquiry)
    assert_response :not_found

    sign_in virginie
    get absence_inquiries_path
    assert_redirected_to absence_inquiry_path(inquiry), "a single open question opens directly"
    assert_predicate other, :persisted?
  end

  test "P5: with three members everyone is asked, and the summary counts each answer" do
    household, (virginie, karim) = couple
    karine = join(household, "Karine", at: JOINED.call)
    household.update_columns(created_at: JOINED.call)
    household.household_members.update_all(created_at: JOINED.call)
    log_balanced_week!(household, [ virginie, karim, karine ], week(0))
    log!(household, virginie, at: mid(week(1)))
    log!(household, karine, at: mid(week(1)))
    log!(household, virginie, at: mid(week(2)))
    log!(household, karine, at: mid(week(2)))
    run_engine(household, final_at(week(2)))
    travel_to(paris(2026, 10, 26, 10))
    inquiry = household.absence_inquiries.pending.sole
    sign_in karine

    post answer_absence_inquiry_path(inquiry), params: { answer: "no" }
    get absence_inquiry_path(inquiry)

    assert_select "h1", "Absence de Karim ?"
    assert_select "#absence-answers .list-row", count: 3
    assert_text "0 oui · 1 non · 2 sans réponse"
    assert_text "Tout le foyer est interrogé, Karim compris"
  end

  # ---- E4 / E15 / F8: blocked, and a pause cancels it ------------------------------------------------------------

  def blocked_household
    household, (virginie, karim) = couple
    two_empty_weeks_for_karim(household, virginie, karim)
    run_engine(household, paris(2026, 10, 28, 21))
    assert_predicate household, :blocked?
    [ household, virginie, karim ]
  end

  test "E4, E15: the regression names who did not log; the person concerned reads it with « vous »" do
    household, virginie, karim = blocked_household
    log!(household, virginie, at: paris(2026, 10, 28, 22), count: 3)
    travel_to(paris(2026, 10, 28, 23))

    sign_in virginie
    get dashboard_path
    assert_select "#alert-blocked" do
      assert_select "h2", "Niveau 0 : Karim n'a rien enregistré depuis 2 semaines"
      assert_page_text "Du 12 oct au 25 oct. Une absence de Karim ?"
      assert_select "a[href=?]", new_member_pause_path(pour: membership(household, karim).id, du: week(1).monday, au: week(2).sunday),
                    text: "Déclarer une pause pour Karim ›"
      assert_text "Une semaine où chaque membre enregistre au moins une tâche."
      assert_select "li", text: /Virginie, depuis lundi\s*3 tâches/
      assert_select "li", text: /Karim, depuis lundi\s*0 tâche/
    end
    get report_path
    assert_select "#alert-blocked", count: 1 # the same alert in the Bilan tab

    sign_in karim
    get dashboard_path
    assert_select "#alert-blocked h2", "Niveau 0 : vous n'avez rien enregistré pendant 2 semaines"
    assert_select "#alert-blocked a[href=?]", new_member_pause_path(du: week(1).monday, au: week(2).sunday), text: "Déclarer une pause ›"
  end

  test "F8: a pause for the absent member cancels the regression, takes no reason and says so" do
    household, virginie, karim = blocked_household
    travel_to(paris(2026, 10, 29, 9))
    sign_in virginie
    target = membership(household, karim)

    get new_member_pause_path(pour: target.id, du: week(1).monday, au: week(2).sunday)
    assert_response :success
    assert_select "h1", "Absence de Karim"
    assert_select "input[name=?][value=?]", "member_pause[starts_on]", "2026-10-12"
    assert_select "input[name=?][value=?]", "member_pause[ends_on]", "2026-10-25"
    assert_select "input[name=?]", "member_pause[reason]", count: 0
    assert_text "La pause annule la descente : le foyer revient au niveau 1, compteur rétabli comme avant."

    post member_pauses_path, params: { member_pause: { household_member_id: target.id, starts_on: "2026-10-12",
                                                       ends_on: "2026-10-25", reason: "secret" } }

    assert_redirected_to member_pauses_path
    assert_equal "Pause déclarée. Elle annule la descente : le foyer revient au niveau 1.", flash[:notice]
    pause = target.member_pauses.sole
    assert_equal virginie, pause.declared_by
    assert_nil pause.reason, "a pause declared for someone else carries no reason"
    assert_equal [ 1, 1 ], [ household.reload.level, household.balanced_weeks_count ]
    assert_not household.blocked?

    sign_in karim
    get member_pauses_path
    assert_select "#pause-#{pause.id}", text: /Du 12 oct au 25 oct · déclarée par Virginie/
    get dashboard_path
    assert_select "#alert-level h2", "Descente annulée : niveau 1"
  end

  test "F8: a pause for someone else is refused when no regression is waiting for it" do
    household, (virginie, karim) = couple
    travel_to(paris(2026, 10, 14, 10))
    sign_in virginie

    get new_member_pause_path(pour: membership(household, karim).id)
    assert_redirected_to member_pauses_path
    follow_redirect!
    assert_select ".alert-box", text: /seulement après une descente de niveau/

    post member_pauses_path, params: { member_pause: { household_member_id: membership(household, karim).id, starts_on: "2026-10-14" } }
    assert_redirected_to member_pauses_path
    assert_empty household.member_pauses
  end

  test "E5: the block lifted is announced without naming anyone" do
    household, virginie, karim = blocked_household
    log_balanced_week!(household, [ virginie, karim ], week(3))
    run_engine(household, final_at(week(3)))
    assert_not household.blocked?
    travel_to(paris(2026, 11, 2, 10))
    sign_in karim

    get dashboard_path

    assert_select "#alert-unblocked" do
      assert_select "h2", "Progression débloquée."
      assert_text "Chaque membre a enregistré des tâches"
      assert_text "La semaine est aussi équilibrée : elle compte."
      assert_select "a[href=?]", report_path(semaine: week(3).monday.iso8601)
    end
    assert_select "#alert-unblocked", text: /Virginie|Karim/, count: 0
    assert_select "#alert-blocked", count: 0
  end

  # ---- F6, F10: pauses ------------------------------------------------------------------------------------------------------

  test "F6, F10: a pause for oneself, its reason private, the dates visible to all, stopped and edited by its author only" do
    household, (virginie, karim) = couple
    travel_to(paris(2026, 10, 14, 10))
    sign_in karim

    get new_member_pause_path
    assert_response :success
    assert_select "h1", "Déclarer une pause"
    assert_select "input[name=?][value=?]", "member_pause[starts_on]", "2026-10-14"
    assert_text "À deux, les semaines de pause sont neutres"
    assert_text "Visible uniquement par vous."

    post member_pauses_path, params: { member_pause: { starts_on: "2026-10-14", ends_on: "2026-10-20", reason: "Vacances en famille" } }
    assert_redirected_to member_pauses_path
    assert_equal "Pause déclarée.", flash[:notice]
    pause = membership(household, karim).member_pauses.sole
    assert_equal [ karim, "Vacances en famille" ], [ pause.declared_by, pause.reason ]

    get member_pauses_path
    assert_select "#own-pause h2", "Vous êtes en pause"
    assert_text "jour 1 sur 7"
    assert_select "#pause-reason-#{pause.id}", text: /Vacances en famille/

    # The household sees the dates, never the reason.
    sign_in virginie
    get member_pauses_path
    assert_select "#pause-#{pause.id}", text: /Karim.*Du 14 oct au 20 oct/m
    assert_not response.body.include?("Vacances en famille")
    assert_select "#own-pause", count: 0
    post stop_member_pause_path(pause)
    assert_response :not_found
    get edit_member_pause_path(pause)
    assert_response :not_found
    assert_equal Date.new(2026, 10, 20), pause.reload.ends_on

    sign_in karim
    patch member_pause_path(pause), params: { member_pause: { ends_on: "2026-10-25" } }
    assert_redirected_to member_pauses_path
    assert_equal Date.new(2026, 10, 25), pause.reload.ends_on
    patch member_pause_path(pause), params: { member_pause: { ends_on: "2026-10-01" } }
    assert_response :unprocessable_entity
    assert_field_error "La fin de la pause ne peut pas être dans le passé."

    post stop_member_pause_path(pause)
    assert_redirected_to member_pauses_path
    assert_equal Date.new(2026, 10, 14), pause.reload.ends_on, "ends today"
    assert_equal "Pause arrêtée.", flash[:notice]
  end

  test "F6: the retroactive limit is explained on the form" do
    household, (_, karim) = couple
    travel_to(paris(2026, 11, 20, 10))
    sign_in karim

    post member_pauses_path, params: { member_pause: { starts_on: "2026-10-01" } }

    assert_response :unprocessable_entity
    assert_field_error "Une pause peut commencer au plus 14 jours en arrière."
    assert_empty household.member_pauses
  end

  test "F1: the household screen offers « Déclarer une pause » and the list of pauses" do
    household, (virginie, _) = couple
    travel_to(paris(2026, 10, 14, 10))
    sign_in virginie

    get household_path(household)

    assert_select "a.list-row[href=?]", new_member_pause_path, text: /Déclarer une pause/
    assert_select "a.list-row[href=?]", member_pauses_path, text: /Pauses/
  end

  # ---- Notification links ------------------------------------------------------------------------------------------------------

  test "every notification kind lands on a screen of the app" do
    household, (virginie, _) = couple
    travel_to(paris(2026, 10, 14, 10))
    sign_in virginie
    expected = {
      "weekly_report" => report_path(semaine: "2026-10-05"),
      "reengagement" => dashboard_path,
      "alert_no_logs" => dashboard_path,
      "alert_blocked" => dashboard_path,
      "alert_unblocked" => dashboard_path,
      "absence_question" => absence_inquiries_path,
      "absence_outcome" => member_pauses_path,
      "pause_declared" => member_pauses_path,
      "task_assigned" => chores_path,
      "monday_split" => chores_path,
      "household_ready" => dashboard_path
    }

    Notifications::Catalogue.kinds.each do |kind|
      notification = Notification.create!(user: virginie, household: household, kind: kind, dedup_key: "link-#{kind}",
                                          event_type: Notifications::Catalogue.fetch(kind).event_type,
                                          facts: { "week_start" => "2026-10-05" }, deliver_at: 1.hour.ago)

      get notification_path(notification)

      assert_response :redirect, kind
      assert_redirected_to expected.fetch(kind) { response.location }, kind if expected.key?(kind)
      follow_redirect!
      assert_response :success, "#{kind} -> #{response.request.path}"
    end
    assert_equal({ semaine: "2026-10-05" }, Notifications::Catalogue.path_options(Notification.new(kind: "weekly_report", facts: { "week_start" => "2026-10-05" })))
    assert_equal({}, Notifications::Catalogue.path_options(Notification.new(kind: "alert_blocked", facts: { "week_start" => "2026-10-05" })))
  end
end
