# What the team did from the back office, and who got in or tried to. One row
# per event, kept for good: read-only once saved, append-only in the database
# (a trigger refuses UPDATE, DELETE and TRUNCATE), shown read-only in the
# admin ("Journal").
#
# `action` is one of ACTIONS. `record` is what it was done to; `detail` is a
# small hash of ids and states, never a name or anything a person wrote (the
# people concerned may delete their account later). Where an address has to be
# told apart, `AdminAction.digest` gives a keyed digest, not the address.
# Sign-in events also keep the client IP.
class AdminAction < ApplicationRecord
  include BackOfficeSearchable

  # The actor of a rake task: there is no signed-in person.
  CONSOLE = "console".freeze

  ACTIONS = %w[
    admin.signed_in admin.sign_in_failed admin.locked
    admin.bootstrapped admin.password_reset admin.two_factor_reset
    two_factor.enrolled two_factor.enrolment_failed
    invitation.resent invitation.cancelled
    household.unblocked
    user.email_confirmed user.email_change_confirmed user.account_deleted
    user.sign_in_unlocked
  ].freeze

  belongs_to :admin_user, optional: true
  belongs_to :record, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :admin_email, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  self.ransackable_attribute_names = %w[action admin_email record_type record_id created_at]

  def self.record!(admin:, action:, record: nil, **detail)
    record_event!(action: action, email: admin.email, admin: admin, record: record, **detail)
  end

  # `email` is who did it: the admin's, "console" for a rake task, or the
  # address typed on a failed sign-in (cut short: it is attacker-controlled).
  def self.record_event!(action:, email:, admin: nil, record: nil, **detail)
    create!(admin_user: admin, admin_email: email.to_s.strip.first(120).presence || "inconnu", action: action,
            record_type: record&.class&.base_class&.name, record_id: record&.id, detail: detail.as_json)
  end

  def self.record_console!(action:, record: nil, **detail)
    record_event!(action: action, email: CONSOLE, record: record, **detail)
  end

  # Keyed (HMAC) so an address cannot be recovered from it by trying guesses.
  def self.digest(value)
    key = Rails.application.key_generator.generate_key("admin-actions-digest")
    OpenSSL::HMAC.hexdigest("SHA256", key, value.to_s.downcase)[0, 16]
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
