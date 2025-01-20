class CreateHouseholdMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :household_members do |t|
      t.references :user, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.timestamps
    end
  end
end
