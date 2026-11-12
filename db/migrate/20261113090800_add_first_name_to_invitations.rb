# The invited person's first name, asked on B3 (decision of the product owner,
# 2026-11-12): pending invitees are shown by it in the starting split, the
# assignees, the week plans and the invitation screens. Nullable: invitations
# sent before it have none (Invitation#display_name falls back on the email).
class AddFirstNameToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :first_name, :string
  end
end
