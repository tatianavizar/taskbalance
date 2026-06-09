class RecurringChoreScheduler
  FREQUENCY_DURATION = {
    "daily"    => 1.day,
    "weekly"   => 1.week,
    "monthly"  => 1.month,
    "annually" => 1.year
  }.freeze

  # Call site today (inline):
  #   RecurringChoreScheduler.generate_next(recurring_chore)
  #
  # Call site with Sidekiq later (one-line change in controller):
  #   RecurringChoreSchedulerJob.perform_later(recurring_chore.id)
  #   — the job calls RecurringChoreScheduler.generate_next(RecurringChore.find(id))

  def self.generate_next(recurring_chore)
    new(recurring_chore).generate_next
  end

  # Safety net: call on household load to catch any missed generations
  # (e.g. a recurring chore was never marked done so generate_next never fired)
  def self.sync_household(household)
    household.recurring_chores.active.each do |rc|
      new(rc).ensure_pending_exists
    end
  end

  def initialize(recurring_chore)
    @rc = recurring_chore
  end

  def generate_next
    return unless @rc.active?

    @rc.chores.create!(
      household_id:      @rc.household_id,
      task_id:           @rc.task_id,
      assigned_to_id:    @rc.assigned_to_id,
      time_required:     @rc.time_required,
      mental_load:       @rc.mental_load,
      execution_load:    @rc.execution_load,
      status:            :pending,
      due_date:          next_due_date
    )
  end

  def ensure_pending_exists
    return if @rc.chores.pending.exists?
    return if next_due_date > Date.today

    generate_next
  end

private

  def next_due_date
    last_due = @rc.chores.maximum(:due_date) || Date.today
    last_due + FREQUENCY_DURATION.fetch(@rc.frequency)
  end
end
