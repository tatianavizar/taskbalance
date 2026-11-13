# One setting per event type and per person (D9). The channel is not part of
# it: an event goes by push when the person has a device that accepts it,
# otherwise by email (Notifications::Notifier).
#
# Rows exist only once someone changed a setting; everything else follows
# DEFAULTS. All five are on by default (F4, H4: "Vous recevez toujours le bilan
# et les alertes par email"). Push permission, which starts off, is a different
# thing and belongs to lot 8b.
class NotificationPreference < ApplicationRecord
  # The rows of F4, in display order.
  EVENT_TYPES = %w[weekly_report task_assigned alert monday_split absence_question].freeze
  DEFAULTS = EVENT_TYPES.index_with { true }.freeze

  belongs_to :user

  validates :event_type, inclusion: { in: EVENT_TYPES }, uniqueness: { scope: :user_id }

  # { "weekly_report" => true, ... } with the person's choices over the defaults.
  def self.settings_for(user)
    DEFAULTS.merge(where(user_id: user.id).pluck(:event_type, :enabled).to_h)
  end

  def self.enabled?(user, event_type)
    row = find_by(user_id: user.id, event_type: event_type.to_s)
    row ? row.enabled : DEFAULTS.fetch(event_type.to_s)
  end

  def self.set(user, event_type, enabled)
    preference = find_or_initialize_by(user_id: user.id, event_type: event_type.to_s)
    preference.update!(enabled: enabled)
    preference
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
