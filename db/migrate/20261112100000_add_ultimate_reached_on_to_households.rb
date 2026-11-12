# Monday of the week the household first reached the ultimate level: the
# start of the window that keeps it (capped at 52 weeks). Never reset.
class AddUltimateReachedOnToHouseholds < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :ultimate_reached_on, :date
  end
end
