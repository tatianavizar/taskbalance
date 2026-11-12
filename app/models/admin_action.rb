# What the team did from the back office. One row per write, kept for good:
# read-only once saved, shown read-only in the admin ("Journal").
#
# `action` is one of ACTIONS. `record` is what it was done to; `detail` is a
# small hash of ids and states, never a name, an email or anything a person
# wrote (the people concerned may delete their account later).
class AdminAction < ApplicationRecord
  include BackOfficeSearchable

  ACTIONS = %w[
    two_factor.enrolled
    invitation.resent invitation.cancelled
    household.unblocked
    user.email_confirmed user.account_deleted
  ].freeze

  belongs_to :admin_user, optional: true
  belongs_to :record, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :admin_email, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  self.ransackable_attribute_names = %w[action admin_email record_type record_id created_at]

  def self.record!(admin:, action:, record: nil, **detail)
    create!(admin_user: admin, admin_email: admin.email, action: action,
            record_type: record&.class&.base_class&.name, record_id: record&.id, detail: detail.as_json)
  end

  # `record` can point at a row that was deleted since; the type and id stay.
  def record
    super
  rescue NameError
    nil
  end

  def readonly?
    super || persisted?
  end
end
