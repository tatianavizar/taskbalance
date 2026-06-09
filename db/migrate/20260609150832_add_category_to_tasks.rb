class AddCategoryToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :category, :string, null: false, default: "other"
  end
end
