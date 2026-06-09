class AddLoadDimensionsToChores < ActiveRecord::Migration[8.0]
  def change
    add_column :chores, :mental_load, :boolean, default: false, null: false
    add_column :chores, :execution_load, :boolean, default: false, null: false
  end
end
