# Lot 3: an invitation has a state, an expiry, a send history and, once the
# invited person has an account and works through the setup, an invitee.
class AddLifecycleToInvitations < ActiveRecord::Migration[8.0]
  def up
    add_column :invitations, :state, :string, null: false, default: "pending"
    add_column :invitations, :expires_at, :datetime
    add_column :invitations, :last_sent_at, :datetime
    add_column :invitations, :resend_count, :integer, null: false, default: 0
    add_column :invitations, :accepted_at, :datetime
    add_column :invitations, :declined_at, :datetime
    add_column :invitations, :cancelled_at, :datetime
    add_reference :invitations, :invitee, foreign_key: { to_table: :users, on_delete: :nullify }
    add_reference :invitations, :inviter, foreign_key: { to_table: :users, on_delete: :nullify }

    execute "UPDATE invitations SET expires_at = created_at + interval '14 days', last_sent_at = created_at"
    change_column_null :invitations, :expires_at, false
    change_column_null :invitations, :last_sent_at, false

    # An email can be invited again once the earlier invitation is closed, so
    # only one *pending* invitation per email and household.
    remove_index :invitations, column: %i[email household_id]
    add_index :invitations, %i[email household_id], unique: true, where: "state = 'pending'",
              name: "index_invitations_pending_on_email_and_household_id"
    add_index :invitations, %i[household_id email], name: "index_invitations_on_household_id_and_email"
  end

  def down
    remove_index :invitations, name: "index_invitations_on_household_id_and_email"
    remove_index :invitations, name: "index_invitations_pending_on_email_and_household_id"
    # Closed rows would collide with the old full unique index: keep the latest.
    execute <<~SQL
      DELETE FROM invitations a USING invitations b
      WHERE a.email = b.email AND a.household_id = b.household_id AND a.id < b.id
    SQL
    add_index :invitations, %i[email household_id], unique: true
    remove_reference :invitations, :inviter, foreign_key: { to_table: :users }
    remove_reference :invitations, :invitee, foreign_key: { to_table: :users }
    %i[cancelled_at declined_at accepted_at resend_count last_sent_at expires_at state].each do |column|
      remove_column :invitations, column
    end
  end
end
