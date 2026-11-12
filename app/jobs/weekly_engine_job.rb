# Recurring (config/recurring.yml, every 15 minutes): runs the weekly engine of
# every household, then tells the members what the run produced (lot 8a).
# Safe to run at any time and as often as wanted: the engine is idempotent and
# so are the notifications (Notifications::Notifier).
#
# It loops over the households itself, like WeeklyEngine.run_all, because
# run_all drops each WeeklyEngine::Result and the notifications are built from
# it. A failure in one household is reported and the others go on; a failure
# while notifying never undoes what the engine did.
class WeeklyEngineJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    Household.find_each do |household|
      result = WeeklyEngine.new(household).run(now: now)
      notify(household, result, now)
    rescue StandardError => e
      Rails.error.report(e, context: { household_id: household.id })
    end
  end

  private

  def notify(household, result, now)
    Notifications::Dispatcher.engine_result(household, result, now: now)
  rescue StandardError => e
    Rails.error.report(e, context: { household_id: household.id, step: "notifications" })
  end
end
