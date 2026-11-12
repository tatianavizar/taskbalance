# Preview at /rails/mailers/notification_mailer. Nothing is saved: the
# notifications are built in memory, for Virginie (viewer) in a household of
# two with Karim. The same facts are read by Karim's version in the tests.
class NotificationMailerPreview < ActionMailer::Preview
  VIRGINIE = 1
  KARIM = 2

  def weekly_report_unbalanced
    notify "weekly_report", report_facts(outcome: "unbalanced")
  end

  def weekly_report_balanced
    notify "weekly_report", report_facts(outcome: "balanced", carrier: nil, mental: [ 54, 46 ])
  end

  def weekly_report_neutral
    notify "weekly_report", report_facts(outcome: "neutral", neutral_reason: "no_execution_logs", carrier: nil)
  end

  def reengagement
    notify "reengagement", { "household_name" => "Chez Virginie et Karim", "week_number" => 45 }
  end

  def alert_no_logs_about_me
    notify "alert_no_logs", no_logs_facts(subject: person(VIRGINIE, "Virginie"))
  end

  def alert_no_logs_about_karim
    notify "alert_no_logs", no_logs_facts(subject: person(KARIM, "Karim"))
  end

  def alert_blocked
    notify "alert_blocked", {
      "subject" => person(KARIM, "Karim"), "from_level" => 3, "to_level" => 2,
      "first_week_start" => "2026-02-01", "last_week_end" => "2026-02-14", "weeks" => 2
    }
  end

  def alert_unblocked
    notify "alert_unblocked", { "week_number" => 7, "balanced" => true, "level" => 2, "next_level" => 3 }
  end

  def absence_question
    notify "absence_question", {
      "subject" => person(KARIM, "Karim"), "week_number" => 6, "first_week_start" => "2026-02-01",
      "last_week_end" => "2026-02-14", "weeks" => 2, "deadline_on" => "2026-02-17", "deadline_hour" => "20:00"
    }
  end

  def absence_outcome_paused
    notify "absence_outcome", { "outcome" => "paused", "subject" => person(KARIM, "Karim"), "starts_on" => "2026-02-01", "ends_on" => "2026-02-14" }
  end

  def pause_declared
    notify "pause_declared", { "subject" => person(KARIM, "Karim"), "starts_on" => "2026-02-01", "ends_on" => nil }
  end

  def task_assigned
    notify "task_assigned", { "chore_name" => "Vider le lave-vaisselle", "due_on" => "2026-02-12", "assigned_by" => person(KARIM, "Karim") }
  end

  def monday_split
    notify "monday_split", { "week_number" => 7, "counts" => [ person(VIRGINIE, "Virginie").merge("tasks" => 5), person(KARIM, "Karim").merge("tasks" => 5) ] }
  end

  private

  def person(id, first_name) = { "user_id" => id, "first_name" => first_name }

  def notify(kind, facts)
    user = User.new(id: VIRGINIE, first_name: "Virginie", email: "virginie.martin@example.com")
    entry = Notifications::Catalogue.fetch(kind)
    notification = Notification.new(user: user, kind: kind, event_type: entry.event_type, facts: facts, deliver_at: Time.current)
    NotificationMailer.notify(notification)
  end

  def no_logs_facts(subject:)
    {
      "subject" => subject, "week_start" => "2026-02-01", "week_end" => "2026-02-07", "week_number" => 5,
      "counts" => [ person(VIRGINIE, "Virginie").merge("logs_count" => subject["user_id"] == VIRGINIE ? 0 : 21),
                    person(KARIM, "Karim").merge("logs_count" => subject["user_id"] == KARIM ? 0 : 21) ],
      "recent" => [ { "week_number" => 2, "logs_count" => 9 }, { "week_number" => 3, "logs_count" => 7 },
                    { "week_number" => 4, "logs_count" => 8 }, { "week_number" => 5, "logs_count" => 0 } ]
    }
  end

  def report_facts(outcome:, carrier: :default, mental: [ 72, 28 ], neutral_reason: nil)
    carrier = { "user_id" => VIRGINIE, "first_name" => "Virginie", "dimension" => "mental", "share" => 72 } if carrier == :default
    {
      "week_number" => 45, "provisional" => false, "outcome" => outcome, "neutral_reason" => neutral_reason,
      "fair_share" => 50, "zone_min" => 40, "zone_max" => 60,
      "members" => [
        person(VIRGINIE, "Virginie").merge("mental_share" => mental[0], "execution_share" => 58, "mental_count" => 18, "execution_count" => 18, "minutes" => 600, "logs_count" => 18, "paused" => false),
        person(KARIM, "Karim").merge("mental_share" => mental[1], "execution_share" => 42, "mental_count" => 7, "execution_count" => 13, "minutes" => 310, "logs_count" => 13, "paused" => false)
      ],
      "carrier" => carrier, "level" => 1, "ultimate" => false, "blocked" => false,
      "weeks_to_next_level" => 2, "previous_unbalanced" => 2,
      "history" => [ { "week_number" => 42, "share" => 54, "balanced" => true }, { "week_number" => 43, "share" => 63, "balanced" => false },
                     { "week_number" => 44, "share" => 66, "balanced" => false }, { "week_number" => 45, "share" => mental[0], "balanced" => false } ]
    }
  end
end
