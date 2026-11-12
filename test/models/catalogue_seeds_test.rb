require "test_helper"

# db/seeds.rb: the catalogue in French, with a stable key, default loads and
# a frequency for every task. Running the seeds again changes nothing and
# keeps the chores that use a task.
class CatalogueSeedsTest < ActiveSupport::TestCase
  def seed!
    silence_stream($stdout) { load Rails.root.join("db/seeds.rb") }
  end

  def silence_stream(stream)
    old = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(old)
  end

  test "every task has a key, a French name, at least one load and a frequency" do
    seed!
    seeded = Task.where.not(id: [ tasks(:cook_meal).id, tasks(:do_laundry).id, tasks(:pay_bills).id ])
    assert_operator Task.count, :>=, 49
    Task.find_each do |task|
      assert task.valid?, "#{task.key}: #{task.errors.full_messages.to_sentence}"
      assert task.default_mental_load || task.default_execution_load, "#{task.key} carries no load"
    end
    assert seeded.none? { |task| task.name.match?(/\A(Cook|Do|Clean|Buy|Pay) /) }, "names are in French"
  end

  test "the seeds find tasks by key: a renamed task keeps its chores" do
    chore = chores(:smith_cooking)
    seed!
    assert_equal "Préparer un repas", chore.reload.task.name
    assert_equal "cook_a_meal", chore.task.key

    assert_no_difference "Task.count" do
      seed!
    end
  end
end
