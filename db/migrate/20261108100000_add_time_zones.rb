class AddTimeZones < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :time_zone, :string, null: false, default: "Europe/Paris"
    add_column :users, :time_zone, :string, null: false, default: "Europe/Paris"
  end
end
