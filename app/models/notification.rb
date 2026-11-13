# What 50/50 told one person about one event. It is three things at once:
#
# - the in-app feed (read and unread);
# - the record of what was sent, which makes the weekly cap hold and stops an
#   event from being sent twice (unique on user + dedup_key, and on user +
#   cap_class + cap_week_start for what actually went out);
# - the facts the text is written from. They are the same for every recipient
#   (D8); only the phrasing adapts, at render time (Notifications::Message).
#
# Rows are written by Notifications::Notifier, never by hand.
class Notification < ApplicationRecord
  # "departed": the person left the household before it went out
  # (HouseholdDeparture); neither sent nor shown.
  SUPPRESSED = %w[preference cap stale no_channel departed].freeze
  HIDDEN_FROM_FEED = %w[preference departed].freeze

  belongs_to :user
  belongs_to :household, optional: true

  validates :kind, :event_type, :dedup_key, :deliver_at, presence: true
  validates :suppressed_reason, inclusion: { in: SUPPRESSED }, allow_nil: true

  # What the feed shows: everything that has come due, except what the person
  # switched off or left behind with a household. A capped or stale event
  # stays readable: the facts are still true.
  scope :feed, -> {
    where(deliver_at: ..Time.current)
      .where("notifications.suppressed_reason IS NULL OR notifications.suppressed_reason NOT IN (?)", HIDDEN_FROM_FEED)
      .order(deliver_at: :desc, id: :desc)
  }
  scope :unread, -> { where(read_at: nil) }
  scope :sent, -> { where.not(channel: nil) }

  def self.unread_count_for(user)
    where(user_id: user.id).feed.unread.count
  end

  def self.mark_all_read!(user)
    where(user_id: user.id, read_at: nil).where(deliver_at: ..Time.current)
      .update_all(read_at: Time.current, updated_at: Time.current)
  end

  # Not yet due, about this household, for this person: withdrawn when they
  # leave it, so they get neither the report nor the alerts of a household
  # they are no longer in.
  def self.suppress_for_departure!(user_id:, household_id:, now: Time.current)
    where(user_id: user_id, household_id: household_id, read_at: nil)
      .where("notifications.deliver_at > ?", now)
      .update_all(channel: nil, suppressed_reason: "departed", updated_at: now)
  end

  # Still for this person at sending time: not withdrawn, and, when it is
  # about a household, the person is still one of its members.
  def deliverable?
    return false if suppressed_reason.present?
    return true if household_id.nil?

    HouseholdMember.exists?(household_id: household_id, user_id: user_id)
  end

  def read? = read_at.present?
  def sent? = channel.present?

  def read!
    update!(read_at: Time.current) unless read?
  end

  def message
    Notifications::Message.new(self)
  end
end
