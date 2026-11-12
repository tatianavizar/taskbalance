# Back-office hardening (security review of lot 9).
#
# session_version: bumped to end every session of an admin (the Devise
#   session salt includes it): a 2FA reset, a lost phone, a leaked password.
# enrolment_nonce: part of the one-time enrolment link; replaced when the link
#   is used up or a new one is issued.
# deactivated_at: admins are deactivated, never destroyed, so the audit log
#   keeps pointing at them.
class HardenAdminUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_users, :session_version, :integer, null: false, default: 0
    add_column :admin_users, :enrolment_nonce, :string
    add_column :admin_users, :deactivated_at, :datetime
  end
end
