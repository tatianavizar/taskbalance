# Logging a task (D6, D7, D10), my journal (E6), correcting (E12) and deleting
# (E16) a log.
#
# A log is its author's: the author is always current_user, whatever the
# request carries, and only the author reads the journal, edits or deletes.
# Deleting removes that log only, after a confirmation screen.
class ChoreLogsController < ApplicationController
  WEEKS_PER_PAGE = 4

  before_action :authenticate_user!
  before_action :set_log, only: [ :edit, :update, :delete, :destroy ]

  # E6: my logs across time, the detached ones included.
  def index
    @zone = ActiveSupport::TimeZone[current_user.household&.time_zone || current_user.time_zone] || ActiveSupport::TimeZone["Europe/Paris"]
    @weeks_shown = [ params[:weeks].to_i, WEEKS_PER_PAGE ].max
    first_week = Week.containing(Time.current, @zone.name)
    @since = first_week.monday - (7 * (@weeks_shown - 1))
    logs = current_user.chore_logs.where(completed_at: @zone.local(@since.year, @since.month, @since.day)..)
      .includes(:household).order(completed_at: :desc, id: :desc)
    @weeks = logs.group_by { |log| Week.containing(log.completed_at, @zone.name) }
    @older = current_user.chore_logs.where(completed_at: ...@zone.local(@since.year, @since.month, @since.day)).exists?
  end

  # D6: what was done. Prefilled from a task of the household, or empty.
  def new
    @entry = LogEntry.new(user: current_user, idempotency_key: SecureRandom.uuid, **prefill)
    return redirect_to(dashboard_path, alert: t("log_entries.errors.no_household")) unless @entry.household

    load_form
  end

  # D8 on success (the home, updated); D7 on errors.
  def create
    @entry = LogEntry.new(user: current_user, **entry_params)
    return redirect_to(dashboard_path, alert: t("log_entries.errors.no_household")) unless @entry.household

    if @entry.save
      redirect_to dashboard_path, notice: t("chore_logs.flash.created", chore: @entry.log.chore_name)
    else
      load_form
      render :new, status: :unprocessable_entity
    end
  end

  # E12
  def edit
    @entry = entry_for(@log)
  end

  def update
    @entry = LogEntry.new(user: current_user, log: @log, **entry_params.slice(:mental_load, :execution_load, :time_spent, :day))
    if @entry.update
      redirect_to chore_logs_path, notice: t("chore_logs.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # E16: the confirmation, before anything is deleted.
  def delete
  end

  def destroy
    @log.destroy!
    redirect_to chore_logs_path, notice: t("chore_logs.flash.destroyed")
  end

  private

  # Only the author's own logs: anyone else's is not found.
  def set_log
    @log = current_user.chore_logs.find_by(id: params[:id])
    redirect_to chore_logs_path, alert: t("common.not_authorized") unless @log
  end

  def entry_for(log)
    LogEntry.new(user: current_user, log: log, mental_load: log.mental_load, execution_load: log.execution_load,
                 time_spent: log.time_spent, day: log.completed_on)
  end

  def prefill
    chore = current_user.household&.chores&.active&.find_by(id: params[:chore_id])
    attributes = { day: params[:day].presence }.compact
    return attributes unless chore

    attributes.merge(chore_id: chore.id, mental_load: chore.mental_load, execution_load: chore.execution_load,
                     time_spent: chore.effective_time_required, occurrence_id: params[:occurrence_id])
  end

  def entry_params
    params.fetch(:log_entry, {}).permit(:chore_id, :occurrence_id, :custom_name, :category, :mental_load,
                                        :execution_load, :time_spent, :day, :idempotency_key).to_h.symbolize_keys
  end

  def load_form
    @household = @entry.household
    @chores = @household.chores.active.includes(:task).sort_by { |chore| chore.effective_name.to_s.downcase }
  end
end
