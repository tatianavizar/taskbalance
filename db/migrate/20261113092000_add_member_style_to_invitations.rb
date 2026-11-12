# P2: a person invited to a household of three or more picks their colour and
# letters before joining. They are kept on the invitation and given to the
# membership when the person accepts (if the colour is still free).
class AddMemberStyleToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :color, :string
    add_column :invitations, :monogram, :string
  end
end
