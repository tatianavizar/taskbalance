# One household's turn of the weekly engine, and the fan-out that schedules
# it for many households (1M users, Solid Queue).
#
#   EngineDispatchJob      every 15 min (config/recurring.yml), cheap: claims the
#     -> EngineCycle.enqueue_due   households that have something due and
#                                  enqueues one job each, in batches, on the
#                                  `engine` queue (ActiveJob.perform_all_later)
#   HouseholdEngineJob     one per household: EngineCycle.run
#   WeeklyEngineJob        inline, every household, no selection: dev, tests,
#                          `bin/rails runner WeeklyEngineJob.perform_now`
#
# What makes a household due (enqueue_due):
#   - households.engine_due_at <= now. EngineCycle.run stores there the next
#     moment WeeklyEngine#next_due_at lists (provisional report, final report,
#     absence deadline), so a stopped worker only leaves the household due:
#     the next tick catches up. Households start due, and Household#wake_engine
#     sets it to now when a member arrives or leaves or when the time zone, the
#     set-up step or a split setting changes. Safety net: a run never leaves a
#     household unvisited for more than SAFETY_NET;
#   - an engine_event not delivered yet (the outbox), whoever recorded it.
# A selected household is claimed (engine_claimed_at) so a backlog is not
# enqueued again at the next tick; a claim goes stale after CLAIM_TTL, which
# is how a job lost with its worker is picked up again.
#
# One run (run): the engine, the Monday split (WeeklySplit), the delivery of
# the outbox (Notifications::Dispatcher), then the reschedule. Every step is
# idempotent, and the engine takes a row lock on the household, so two
# overlapping runs for one household never process it twice (HouseholdEngineJob
# also limits concurrency per household, which only saves the wait). A failing
# step does not stop the following ones; the first error is raised at the end
# (the job retries with backoff), engine_due_at is not moved and the claim is
# kept until it goes stale, so the household stays due without being enqueued
# twice at every tick. A failing engine step raises at once.
class EngineCycle
  BATCH_SIZE = 1_000
  CLAIM_TTL = 30.minutes
  SAFETY_NET = 7.days

  # Claims up to BATCH_SIZE due households at a time and enqueues their jobs.
  # Returns how many were enqueued; 0 (and no enqueue) when nothing is due.
  def self.enqueue_due(now: Time.current, batch_size: BATCH_SIZE)
    total = 0
    loop do
      ids = claim_due(now, batch_size)
      break if ids.empty?

      ActiveJob.perform_all_later(ids.map { |id| HouseholdEngineJob.new(id) })
      total += ids.size
      break if ids.size < batch_size
    end
    total
  end

  # Atomic: two dispatchers never get the same household (SKIP LOCKED + the
  # claim), and the index on engine_due_at serves the selection.
  def self.claim_due(now, limit)
    sql = Household.sanitize_sql_array([ <<~SQL, { now: now, stale: now - CLAIM_TTL, limit: limit } ])
      UPDATE households SET engine_claimed_at = :now
      WHERE id IN (
        SELECT id FROM households
        WHERE (engine_claimed_at IS NULL OR engine_claimed_at < :stale)
          AND id IN (
            SELECT id FROM households WHERE engine_due_at <= :now
            UNION
            SELECT household_id FROM engine_events WHERE delivered_at IS NULL
          )
        LIMIT :limit
        FOR UPDATE SKIP LOCKED
      )
      RETURNING id
    SQL
    # Uncached: the query cache (on inside jobs) would replay the UPDATE's result.
    Household.uncached { Household.connection.select_values(sql) }
  end
  private_class_method :claim_due

  # Every household, serially and inline, due or not. A failing household is
  # reported and skipped. Yields (household) after each success.
  def self.run_all(now: Time.current)
    Household.find_each do |household|
      run(household, now: now)
      yield household if block_given?
    rescue StandardError => e
      Rails.error.report(e, context: { household_id: household.id })
    end
  end

  def self.run(household, now: Time.current)
    new(household, now).run
  end

  def initialize(household, now)
    @household = household
    @now = now
  end

  # Returns the WeeklyEngine::Result. Raises the first error, after all steps.
  def run
    started_at = Time.current
    errors = []
    result = WeeklyEngine.new(@household).run(now: @now)
    errors << capture { WeeklySplit.new(@household).run(now: @now) }
    errors << capture { Notifications::Dispatcher.deliver_pending(@household, now: @now) }
    errors.compact!

    if errors.empty?
      reschedule(started_at)
      release_claim
    end
    errors.drop(1).each { |e| Rails.error.report(e, context: { household_id: @household.id }) }
    raise errors.first if errors.any?

    result
  end

  private

  def capture
    yield
    nil
  rescue StandardError => e
    e
  end

  # Not moved when a wake-up came in while the run was in progress
  # (engine_due_at later than the start of the run): it must not be lost.
  def reschedule(started_at)
    due = [ WeeklyEngine.new(@household).next_due_at(@now), @now + SAFETY_NET ].compact.min
    Household.where(id: @household.id).where(engine_due_at: ..started_at).update_all(engine_due_at: due)
  end

  def release_claim
    Household.where(id: @household.id).update_all(engine_claimed_at: nil)
  end
end
