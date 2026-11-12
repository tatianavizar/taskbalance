require "test_helper"
require "benchmark"

# Not part of the default suite (the file name does not end in _test.rb).
# Shows what the dispatcher queries cost with many households:
#
#   HOUSEHOLDS=200000 PARALLEL_WORKERS=1 bin/rails test test/benchmarks/engine_dispatch_benchmark.rb
#
# Households are spread over 12 time zones; 2 % are due, the rest are due in
# the future and none has an undelivered engine_event. Reports, for each
# query, the time and the plan (look for index scans, not sequential scans).
class EngineDispatchBenchmark < ActiveSupport::TestCase
  ZONES = %w[Europe/Paris Europe/London Europe/Berlin America/New_York America/Chicago America/Los_Angeles
             Asia/Kolkata Asia/Tokyo Australia/Sydney America/Sao_Paulo Africa/Casablanca Pacific/Auckland].freeze
  COUNT = Integer(ENV.fetch("HOUSEHOLDS", 50_000))

  setup do
    now = Time.current
    COUNT.times.each_slice(5_000) do |slice|
      Household.insert_all(slice.map do |i|
        { name: "Foyer #{i}", time_zone: ZONES[i % ZONES.size], created_at: now, updated_at: now,
          engine_due_at: (i % 50).zero? ? now - 1.hour : now + 1.day + (i % 1000).minutes,
          chores_scheduled_week: now.to_date.beginning_of_week - 7 }
      end)
    end
    Household.connection.execute("ANALYZE households")
    @now = now
  end

  test "dispatcher query cost" do
    explain = Household.connection.select_values(<<~SQL.squish)
      EXPLAIN SELECT id FROM households WHERE engine_due_at <= '#{@now.utc.to_fs(:db)}'
      UNION SELECT household_id FROM engine_events WHERE delivered_at IS NULL
    SQL
    puts "\n#{COUNT} households"
    puts explain

    seconds = Benchmark.realtime { EngineCycle.enqueue_due(now: @now) } # test adapter: kept in memory
    enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.size
    puts format("EngineCycle.enqueue_due: %.3f s, %d households claimed (%d expected)", seconds, enqueued, (COUNT / 50.0).ceil)
    assert_in_delta (COUNT / 50.0).ceil, enqueued, 10 # fixtures add a few

    nothing = Benchmark.realtime { EngineCycle.enqueue_due(now: @now) }
    puts format("EngineCycle.enqueue_due, nothing left due: %.4f s", nothing)

    # Every household is one week behind: the Monday burst marks the ones
    # without chore in one UPDATE per zone, then the rest of the week is a no-op.
    monday = Benchmark.realtime { RecurringChoreScheduler.enqueue_due(now: @now) }
    puts format("RecurringChoreScheduler.enqueue_due, first tick of the week (%d zones): %.3f s", ZONES.size, monday)
    steady = Benchmark.realtime { RecurringChoreScheduler.enqueue_due(now: @now) }
    puts format("RecurringChoreScheduler.enqueue_due, rest of the week: %.4f s", steady)
  end
end
