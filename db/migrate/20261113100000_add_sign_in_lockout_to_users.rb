# Account lockout after wrong passwords (SignInLockout) and the rolling 24 h
# limit on email changes (AccountsController#update_email), decided on
# 2026-11-13.
#
# failed_sign_ins_at: times of the wrong passwords of the last 2 hours.
# sign_in_locked_at: start of the current (or last) lock.
# sign_in_lockouts_count: locks since the last successful sign-in.
# sign_in_hard_locked_at: the 3rd lock, lifted only from the back office.
# email_changes_requested_at: times of the email changes of the last 24 hours.
class AddSignInLockoutToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :failed_sign_ins_at, :datetime, array: true, null: false, default: []
    add_column :users, :sign_in_locked_at, :datetime
    add_column :users, :sign_in_lockouts_count, :integer, null: false, default: 0
    add_column :users, :sign_in_hard_locked_at, :datetime
    add_column :users, :email_changes_requested_at, :datetime, array: true, null: false, default: []
  end
end
