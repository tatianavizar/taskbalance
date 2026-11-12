# Outbox of what the weekly engine did, for lot 8 (emails, push, in-app feed).
# Nothing is sent here: lot 8 reads `undelivered`, sends, then sets
# delivered_at. Recorded inside the same transaction as the change it
# describes, once per change.
#
# Names and payloads (string keys):
#   absence_inquiry.opened    inquiry_id, household_member_id, user_id, first_name,
#                             first_week_start, last_week_start, deadline_at
#   absence_answer.given      inquiry_id, answer_id, respondent_member_id,
#                             respondent_user_id, answer, changed (re-answer)
#   absence_answer.corrected  inquiry_id, answer_id, respondent_member_id,
#                             original_answer, answer, corrected_by_user_id
#   absence_inquiry.resolved  inquiry_id, household_member_id, user_id, outcome
#                             (paused | regressed | cancelled | reopened)
#   household_week.provisional  week_start, outcome
#   household_week.final      week_start, outcome, and the progression right
#                             after that report: level, balanced_weeks_count, blocked
#   member.first_empty_week   household_member_id, user_id, first_name, week_start (E3)
#   household.unblocked       week_start (subject: the final week that lifted it)
#   level.changed             level_change_id, reason, from_level, to_level,
#                             absence_inquiry_id (every LevelChange, any origin)
#   member_pause.declared     household_member_id, user_id, starts_on, ends_on,
#                             declared_by_id (every pause path)
#   member_pause.updated      same payload: the dates of a pause changed
#   household.admin_unblocked admin_user_id, level, balanced_weeks_count (the back
#                             office lifted the block; no subject, nothing is sent)
#
# Notifications::Dispatcher.deliver_pending drains it: an event is marked
# delivered only after the Notifier ran for it, so a crashed dispatch is
# replayed by the next one, and the Notifier's dedup_key stops duplicates.
class EngineEvent < ApplicationRecord
  NAMES = %w[
    absence_inquiry.opened absence_answer.given absence_answer.corrected absence_inquiry.resolved
    household_week.provisional household_week.final member.first_empty_week household.unblocked
    level.changed member_pause.declared member_pause.updated household.admin_unblocked
  ].freeze

  belongs_to :household
  belongs_to :subject, polymorphic: true, optional: true

  validates :name, inclusion: { in: NAMES }
  validates :occurred_at, presence: true

  scope :undelivered, -> { where(delivered_at: nil).order(:occurred_at, :id) }
  scope :chronological, -> { order(:occurred_at, :id) }

  def self.record!(household:, name:, subject: nil, at: Time.current, **payload)
    create!(household: household, name: name, subject: subject, occurred_at: at, payload: payload.as_json)
  end

  def mark_delivered!(at = Time.current)
    update!(delivered_at: at)
  end
end
