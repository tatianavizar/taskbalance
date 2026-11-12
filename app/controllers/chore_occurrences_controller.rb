# « Fait » on a line of the Tasks tab (D3): one gesture, no form. It logs the
# task as the chore describes it (loads, usual duration), today, for
# current_user only. Anything else (another duration, another day) goes through
# the D6 form.
class ChoreOccurrencesController < ApplicationController
  before_action :authenticate_user!

  def complete
    household = current_user.household
    occurrence = ChoreOccurrence.where(household_id: household&.id).find_by(id: params[:id])
    return redirect_to(chores_path, alert: t("common.not_authorized")) unless occurrence

    chore = occurrence.chore
    return redirect_to(chores_path, alert: t("chore_logs.flash.not_yours")) unless chore.active? && chore.assigned_to?(current_user)

    # Done already, by this person: nothing to add (a second tap on a stale page).
    unless occurrence.done_by?(current_user.id)
      entry = LogEntry.new(user: current_user, chore_id: chore.id, occurrence_id: occurrence.id,
                           mental_load: chore.mental_load, execution_load: chore.execution_load,
                           time_spent: chore.effective_time_required, idempotency_key: params[:idempotency_key])
      return redirect_to(chores_path, alert: entry.errors.full_messages.to_sentence) unless entry.save
    end

    redirect_to chores_path(scope: params[:scope].presence, category: params[:category].presence),
                notice: t("chore_logs.flash.created", chore: chore.effective_name)
  end
end
