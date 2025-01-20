class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :name
      t.integer :time_required
      t.integer :priority
      t.timestamps
    end
  end
end
