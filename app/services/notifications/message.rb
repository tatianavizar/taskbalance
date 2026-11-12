module Notifications
  # The words of a notification, for one recipient (D8). The facts and the
  # figures come from `notification.facts`, identical for every recipient;
  # what changes here is only the phrasing: « vous » when the sentence is about
  # the recipient, the first name when it is about someone else. An imbalance
  # names who carries more; a success names no one.
  #
  #   message = notification.message
  #   message.subject  # email subject
  #   message.title    # the headline, in the feed and at the top of the email
  #   message.lines    # sentences under the title
  #   message.details  # [[label, value], ...] figures, for the report and E3
  #   message.heading  # label of `details`, if any
  #   message.history  # report only: the last weeks, [{ "week_number", "share", "balanced" }]
  #   message.cta      # label of the button
  class Message
    attr_reader :notification

    def initialize(notification)
      @notification = notification
      @facts = notification.facts
    end

    def subject = parts.fetch(:subject)
    def title = parts.fetch(:title)
    def lines = parts.fetch(:lines, [])
    def details = parts.fetch(:details, [])
    def heading = parts[:heading]
    def history = parts.fetch(:history, [])
    def cta = t("cta.#{notification.kind == "weekly_report" ? "report" : "open"}")
    def report? = notification.kind == "weekly_report"

    def footer_note
      key = notification.kind == "weekly_report" ? "same_figures" : "same_words"
      t("footer.#{key}")
    end

    private

    attr_reader :facts

    def parts
      @parts ||= send(notification.kind)
    end

    def viewer_id = notification.user_id

    def t(key, **options)
      I18n.t("notifications.#{key}", **options)
    end

    def m(key, **options)
      t("messages.#{notification.kind}.#{key}", **options)
    end

    # « vous » or the first name of a person from the facts.
    def me?(person) = person && person["user_id"] == viewer_id
    def name(person) = me?(person) ? t("you") : person["first_name"]
    def variant(person) = me?(person) ? "self" : "other"

    def date(iso) = I18n.l(Date.iso8601(iso), format: :short)

    def range(from, to)
      to ? t("range.between", from: date(from), to: date(to)) : t("range.since", from: date(from))
    end

    # ---- H3 -------------------------------------------------------------

    def weekly_report
      members = facts["members"].reject { |x| x["paused"] }
      week = facts["week_number"]
      carrier = facts["carrier"]
      outcome = facts["outcome"]

      subject =
        if outcome == "neutral"
          m("subject.neutral", week: week)
        else
          shares = members.select { |x| x["mental_share"] }.sort_by { |x| [ -x["mental_share"], x["first_name"] ] }
          m("subject.shares", week: week, shares: shares.map { |x| "#{x["first_name"]} #{x["mental_share"]} %" }.to_sentence(two_words_connector: ", ", last_word_connector: ", "))
        end

      title =
        if carrier
          m("headline.carrier.#{variant(carrier)}.#{carrier["dimension"]}", name: name(carrier), share: carrier["share"])
        else
          m("headline.#{outcome}")
        end

      lines = [ m("verdict.#{verdict_key}", **verdict_options), level_line ].compact
      { subject: subject, title: title, lines: lines, details: report_details(facts["members"]), history: facts["history"] }
    end

    def verdict_key
      case facts["outcome"]
      when "neutral" then "neutral.#{facts["neutral_reason"]}"
      when "balanced" then "balanced"
      else facts["carrier"] && facts["carrier"]["share"] > facts["zone_max"].to_i ? "above" : "outside"
      end
    end

    def verdict_options
      { min: facts["zone_min"], max: facts["zone_max"], streak: m("streak", count: facts["previous_unbalanced"]) }
    end

    def level_line
      return m("level.blocked") if facts["blocked"]
      return m("level.ultimate") if facts["ultimate"]

      key = facts["outcome"] == "balanced" ? "is" : "stays"
      m("level.#{key}", level: facts["level"], next: facts["level"] + 1, count: facts["weeks_to_next_level"])
    end

    def report_details(members)
      active = members.reject { |x| x["paused"] }
      list = ->(&value) { active.map { |x| "#{x["first_name"]} #{value.call(x)}" }.join(" · ") }
      [
        [ m("details.mental"), list.call { |x| x["mental_count"] } ],
        [ m("details.execution"), list.call { |x| x["execution_count"] } ],
        [ m("details.time"), list.call { |x| format("%d h %02d", *x["minutes"].to_i.divmod(60)) } ]
      ]
    end

    def reengagement
      title = m("title", week: facts["week_number"], household: facts["household_name"])
      { subject: title, title: title, lines: [ m("line") ] }
    end

    # ---- E3, E4, E5 -------------------------------------------------------

    def alert_no_logs
      subject = facts["subject"]
      week = facts["week_number"]
      who = variant(subject)
      counts = facts["counts"].map { |x| "#{name(x)} #{x["logs_count"]}" }.join(", ")
      lines = [ m("range", from: date(facts["week_start"]), to: date(facts["week_end"])) ]
      lines << m("pause") if who == "self"
      lines << m("counts", week: week, counts: counts)
      {
        subject: m("subject.#{who}", week: week, name: subject["first_name"]),
        title: m("title.#{who}", name: subject["first_name"]),
        lines: lines,
        heading: m("heading.#{who}", name: subject["first_name"]),
        details: facts["recent"].map { |x| [ t("week_short", number: x["week_number"]), m("logs", count: x["logs_count"]) ] }
      }
    end

    def alert_blocked
      subject = facts["subject"]
      key = facts["from_level"] == facts["to_level"] ? "held" : "down"
      who = variant(subject)
      title = m("#{key}.#{who}", level: facts["to_level"], name: subject["first_name"], weeks: facts["weeks"])
      {
        subject: title,
        title: title,
        lines: [ m("range", from: date(facts["first_week_start"]), to: date(facts["last_week_end"])), m("unblock") ]
      }
    end

    def alert_unblocked
      outcome = facts["balanced"] ? (facts["next_level"] ? "balanced" : "balanced_top") : "unbalanced"
      {
        subject: m("title"),
        title: m("title"),
        lines: [ m("everyone", week: facts["week_number"]), m("outcome.#{outcome}", level: facts["next_level"]), m("streak") ]
      }
    end

    # ---- the absence question and what follows -----------------------------

    def absence_question
      subject = facts["subject"]
      who = variant(subject)
      deadline = t("deadline", day: I18n.l(Date.iso8601(facts["deadline_on"]), format: "%A"), hour: facts["deadline_hour"])
      title = m("title.#{who}", week: facts["week_number"], name: subject["first_name"])
      {
        subject: title,
        title: title,
        lines: [ m("ask.#{who}", name: subject["first_name"], deadline: deadline), m("rule", deadline: deadline) ]
      }
    end

    def absence_outcome
      subject = facts["subject"]
      who = variant(subject)
      options = { name: subject["first_name"], range: range(facts["starts_on"], facts["ends_on"]) }
      title = m("#{facts["outcome"]}.title.#{who}", **options)
      { subject: title, title: title, lines: [ m("#{facts["outcome"]}.line.#{who}", **options) ] }
    end

    def pause_declared
      subject = facts["subject"]
      title = m("title.#{variant(subject)}", name: subject["first_name"], range: range(facts["starts_on"], facts["ends_on"]))
      { subject: title, title: title, lines: [ m("line") ] }
    end

    # ---- the rest ---------------------------------------------------------

    def task_assigned
      by = facts["assigned_by"]
      title = m("title", name: by["first_name"], chore: facts["chore_name"])
      lines = facts["due_on"] ? [ m("due", date: date(facts["due_on"])) ] : []
      { subject: title, title: title, lines: lines }
    end

    def monday_split
      counts = facts["counts"].map { |x| "#{name(x)} #{x["tasks"]}" }.join(", ")
      title = m("title", week: facts["week_number"])
      { subject: title, title: title, lines: [ m("counts", counts: counts) ] }
    end

    def gap_reset
      title = m("title", week: facts["week_number"])
      { subject: title, title: title }
    end

    def household_ready
      title = m("title", household: facts["household_name"])
      { subject: title, title: title, lines: [ m("line") ] }
    end

    def household_deleted
      title = m("title", name: facts.dig("deleted_by", "first_name"), household: facts["household_name"])
      { subject: title, title: title, lines: [ m("journal"), m("next") ] }
    end
  end
end
