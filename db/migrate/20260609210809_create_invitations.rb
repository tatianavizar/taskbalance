class CreateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.bigint :household_id, null: false
      t.string :token, null: false
      t.timestamp :created_at, null: false
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [:email, :household_id], unique: true
    add_foreign_key :invitations, :households
  end
end
