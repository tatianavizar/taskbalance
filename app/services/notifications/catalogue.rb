module Notifications
  # Every event 50/50 can announce (docs/plan-de-travail.md §3, H1, F4).
  #
  #   event_type  the setting (NotificationPreference) that governs it. F4 has
  #               five rows, so the events that have none of their own share
  #               the closest one: a pause and its outcome follow
  #               "Question d'absence"; the gap reset and « Prêt » (B12) follow
  #               "Répartition du lundi".
  #   cap         "report" or "alert": at most one of each per person and per
  #               week, all channels together (D9). nil: not capped.
  #   target      the route a tap opens (`<target>_path`), for the e-mail
  #               button, the feed and, in lot 8b, the push payload.
  Entry = Data.define(:kind, :event_type, :cap, :target)

  module Catalogue
    ENTRIES = [
      Entry.new("weekly_report",    "weekly_report",    "report", :report),
      Entry.new("reengagement",     "weekly_report",    "report", :dashboard), # instead of the report, empty week
      Entry.new("alert_no_logs",   "alert",            "alert",  :dashboard), # E3
      Entry.new("alert_blocked",    "alert",            "alert",  :dashboard), # E4
      Entry.new("alert_unblocked",  "alert",            "alert",  :dashboard), # E5
      Entry.new("task_assigned",    "task_assigned",    nil,      :chores),
      Entry.new("monday_split",     "monday_split",     nil,      :chores),
      Entry.new("gap_reset",        "monday_split",     nil,      :chores),
      Entry.new("household_ready",  "monday_split",     nil,      :dashboard), # B12 « Prêt »
      Entry.new("absence_question", "absence_question", nil,      :dashboard),
      Entry.new("absence_outcome",  "absence_question", nil,      :dashboard),
      Entry.new("pause_declared",   "absence_question", nil,      :dashboard),
      # Lot 7, F3. No F4 row of its own: follows "alert", never capped.
      Entry.new("household_deleted", "alert",           nil,      :dashboard)
    ].index_by(&:kind).freeze

    def self.fetch(kind) = ENTRIES.fetch(kind.to_s)
    def self.kinds = ENTRIES.keys
  end
end
