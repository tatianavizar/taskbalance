# Delivers a household's pending engine_events now, instead of waiting for
# the next WeeklyEngineJob. Enqueued after a pause is declared (any path: own
# pause, an E11 "Oui", a pause after a regression). Idempotent.
class NotificationsDispatchJob < ApplicationJob
  queue_as :default

  def perform(household_id)
    household = Household.find_by(id: household_id) or return
    Notifications::Dispatcher.deliver_pending(household)
  end
end
