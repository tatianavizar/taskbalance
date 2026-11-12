# Recurring (config/recurring.yml, every 15 minutes): runs the weekly engine of
# every household (WeeklyEngine.run_all, the only loop), then delivers what
# each run recorded in the engine_events outbox (Notifications::Dispatcher).
# Safe to run at any time and as often as wanted: the engine is idempotent,
# and an event is marked delivered only once notified, so a dispatch that
# failed is replayed next time without duplicates. A failure while notifying
# never undoes what the engine did.
class WeeklyEngineJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    WeeklyEngine.run_all(now: now) do |household, _result|
      Notifications::Dispatcher.deliver_pending(household, now: now)
    rescue StandardError => e
      Rails.error.report(e, context: { household_id: household.id, step: "notifications" })
    end
  end
end
