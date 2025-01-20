class CreateChores < ActiveRecord::Migration[8.0]
  def change
    create_table :chores do |t|
      t.references :task, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :status, default: 0
      t.timestamps
    end
  end
end
