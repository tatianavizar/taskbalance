require "test_helper"

# D18: preferences first, then balance the planned occurrences toward the
# fair share. Deterministic.
class SplitProposalTest < ActiveSupport::TestCase
  Item = SplitProposal::Item
  V = "user:1"
  K = "user:2"

  def propose(items, preferences: {}, fixed: {}, keys: [ V, K ], targets: nil)
    SplitProposal.new(items: items, participant_keys: keys, preferences: preferences, fixed: fixed, targets: targets).call
  end

  def shares(items, result, keys: [ V, K ])
    assigned = items.map { |i| Struct.new(:occurrences, :mental_load, :execution_load, :assignees).new(i.occurrences, i.mental_load, i.execution_load, result[i.chore_id]) }
    PlannedSplit.shares_for(assigned, keys)
  end

  def exec(id, occurrences) = Item.new(chore_id: id, occurrences: occurrences, mental_load: false, execution_load: true)
  def mental(id, occurrences) = Item.new(chore_id: id, occurrences: occurrences, mental_load: true, execution_load: false)

  test "every chore gets exactly one assignee" do
    items = [ exec(1, 7), exec(2, 1), mental(3, 1) ]
    result = propose(items)
    assert_equal [ 1, 2, 3 ], result.keys.sort
    assert(result.values.all? { |keys| keys.size == 1 })
  end

  test "without preferences, equal chores split 50/50" do
    items = [ exec(1, 7), exec(2, 7), mental(3, 1), mental(4, 1) ]
    s = shares(items, propose(items))
    assert_in_delta 50, s[V].execution, 0.01
    assert_in_delta 50, s[V].mental, 0.01
  end

  test "a liked chore goes to whoever likes it" do
    items = [ exec(1, 7), exec(2, 7) ]
    result = propose(items, preferences: { K => { 1 => "like" } })
    assert_equal [ K ], result[1]
    assert_equal [ V ], result[2]
  end

  test "a disliked chore goes to someone else" do
    items = [ exec(1, 7), exec(2, 7) ]
    result = propose(items, preferences: { V => { 1 => "dislike" } })
    assert_equal [ K ], result[1]
  end

  test "a chore everyone dislikes still gets an assignee" do
    items = [ exec(1, 3) ]
    result = propose(items, preferences: { V => { 1 => "dislike" }, K => { 1 => "dislike" } })
    assert_equal 1, result[1].size
  end

  test "balancing moves neutral chores before liked ones" do
    # K likes everything: preferences alone would give K 100 %.
    items = [ exec(1, 7), exec(2, 7), exec(3, 1), exec(4, 1) ]
    likes = { K => { 1 => "like", 2 => "like", 3 => "like", 4 => "like" } }
    s = shares(items, propose(items, preferences: likes))
    assert_in_delta 50, s[V].execution, 0.01
  end

  test "balancing never hands a chore to someone who dislikes it" do
    items = [ exec(1, 7), exec(2, 7), exec(3, 7) ]
    dislikes = { V => { 1 => "dislike", 2 => "dislike", 3 => "dislike" } }
    result = propose(items, preferences: dislikes)
    assert(result.values.all? { |keys| keys == [ K ] })
  end

  test "it gets as close as the chores allow and both charges count" do
    # 7 + 3 + 1 execution: the closest split is 7 vs 4.
    items = [ exec(1, 7), exec(2, 3), exec(3, 1), mental(4, 1), mental(5, 1) ]
    result = propose(items)
    s = shares(items, result)
    assert_in_delta 7.0 / 11 * 100, [ s[V].execution, s[K].execution ].max, 0.01
    assert_in_delta 50, s[V].mental, 0.01
  end

  test "fixed chores keep their assignees and count in the load" do
    items = [ exec(1, 7), exec(2, 7), exec(3, 7) ]
    # Chore 1 is shared: it counts in full for both.
    result = propose(items, fixed: { 1 => [ V, K ] })
    assert_equal [ V, K ], result[1]
    assert_not_equal result[2], result[3]
  end

  test "targets other than the fair share are followed (lot 6 compensation)" do
    items = (1..10).map { |id| exec(id, 1) }
    s = shares(items, propose(items, targets: { V => 40.0, K => 60.0 }))
    assert_in_delta 40, s[V].execution, 0.01
  end

  test "three people share toward a third each" do
    keys = [ V, K, "user:3" ]
    items = (1..9).map { |id| exec(id, 1) }
    s = shares(items, propose(items, keys: keys), keys: keys)
    keys.each { |key| assert_in_delta 33.33, s[key].execution, 0.01 }
  end

  test "the same input always gives the same split" do
    items = [ exec(1, 7), exec(2, 7), exec(3, 2), mental(4, 1), mental(5, 4), exec(6, 3) ]
    preferences = { V => { 4 => "like" }, K => { 6 => "dislike" } }
    first = propose(items, preferences: preferences)
    assert_equal first, propose(items.reverse, preferences: preferences)
  end

  test "for_household reads the members' preferences, and never moves a kept chore" do
    household = households(:smith_home)
    cooking = chores(:smith_cooking)
    laundry = chores(:smith_laundry)
    ChorePreference.create!(user: users(:bob), chore: cooking, choice: "like")

    result = SplitProposal.for_household(household)
    assert_equal [ "user:#{users(:bob).id}" ], result[cooking.id]

    kept = SplitProposal.for_household(household, keep: [ cooking.id ])
    assert_equal [ "user:#{users(:alice).id}" ], kept[cooking.id]
    assert result.key?(laundry.id)
  end
end
