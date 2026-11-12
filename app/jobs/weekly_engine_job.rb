# Recurring (config/recurring.yml, every 15 minutes): runs the weekly engine of
# every household. Safe to run at any time and as often as wanted.
class WeeklyEngineJob < ApplicationJob
  queue_as :default

  def perform
    WeeklyEngine.run_all
  end
end
