require "test_helper"

class WeeklyStatsTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    @week = Week.containing(Date.new(2026, 10, 5), PARIS) # Mon 5 – Sun 11 Oct 2026
    @wednesday = paris(2026, 10, 7, 18)
  end

  def stats(household, week = @week) = WeeklyStats.new(household, week)

  # Logs per user: [mental-only, execution-only] counts.
  def log_split!(household, users_counts)
    users_counts.each do |user, (mental, execution)|
      log!(household, user, at: @wednesday, mental: true, execution: false, count: mental) if mental.positive?
      log!(household, user, at: @wednesday, mental: false, execution: true, count: execution) if execution.positive?
    end
  end

  test "two members at 50/50 on both dimensions: balanced, fair share 50, zone 40-60" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log!(household, alice, at: @wednesday, count: 3)
    log!(household, bob, at: @wednesday, count: 3)

    s = stats(household)
    assert_equal 50, s.fair_share
    assert_equal 40..60, s.zone
    assert_equal :balanced, s.outcome
    assert_nil s.neutral_reason
    assert_equal [ 50, 50 ], s.members.map(&:mental_share)
    assert_equal [ 50, 50 ], s.members.map(&:execution_share)
    assert_equal 6, s.mental_total
    assert_equal 6, s.execution_total
    assert_equal 60, s.minutes_total
    assert s.member_for(alice).in_zone
    assert_equal "Bob", s.member_for(bob.id).first_name
  end

  test "40 % and 60 % are inside the zone" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log_split!(household, alice => [ 2, 3 ], bob => [ 3, 2 ])

    s = stats(household)
    assert_equal [ 40, 60 ], s.members.map(&:mental_share)
    assert_equal [ 60, 40 ], s.members.map(&:execution_share)
    assert s.balanced?
  end

  test "39 % and 61 % are outside the zone: unbalanced" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log_split!(household, alice => [ 7, 1 ], bob => [ 11, 1 ]) # 7/18 = 38.9 %

    s = stats(household)
    assert_equal [ 39, 61 ], s.members.map(&:mental_share)
    assert s.unbalanced?
    assert_not s.member_for(alice).in_zone_mental
    assert s.member_for(alice).in_zone_execution
  end

  # Bulk logs carrying both dimensions: { user => count }.
  def bulk_log!(household, counts)
    rows = counts.flat_map do |user, n|
      Array.new(n) { { user_id: user.id, household_id: household.id, chore_name: "Ménage", mental_load: true, execution_load: true, time_spent: 5, completed_at: @wednesday } }
    end
    ChoreLog.insert_all!(rows)
  end

  # Two members, fair share 50, zone 40-60. The zone judges the exact share;
  # the rounded share is for display only.
  {
    [ 79, 121 ] => [ 39.5, 60.5, false, false, 40, 61 ],
    [ 2, 3 ] => [ 40.0, 60.0, true, true, 40, 60 ],
    [ 302, 198 ] => [ 60.4, 39.6, false, false, 60, 40 ]
  }.each do |(a, b), (exact_a, exact_b, in_a, in_b, shown_a, shown_b)|
    test "zone boundary on the exact share: #{exact_a} % and #{exact_b} %" do
      household, (alice, bob) = build_household("Alice", "Bob")
      bulk_log!(household, alice => a, bob => b)

      s = stats(household)
      alice_stats, bob_stats = s.member_for(alice), s.member_for(bob)
      assert_equal [ exact_a, exact_b ], [ alice_stats.mental_share_exact.to_f, bob_stats.execution_share_exact.to_f ]
      assert_kind_of Rational, alice_stats.mental_share_exact
      assert_equal [ shown_a, shown_b ], [ alice_stats.mental_share, bob_stats.mental_share ]
      assert_equal [ in_a, in_b ], [ alice_stats.in_zone, bob_stats.in_zone ]
      assert_equal (in_a && in_b), s.balanced?
    end
  end

  test "39.5 % is shown as 40 % but is out of the zone, and the snapshot keeps both values" do
    household, (alice, bob) = build_household("Alice", "Bob")
    bulk_log!(household, alice => 79, bob => 121)

    member = stats(household).to_snapshot[:members].first
    assert_equal 40, member["mental_share"]
    assert_equal 39.5, member["mental_share_exact"]
    assert_equal 39.5, member["execution_share_exact"]
    assert_equal false, member["in_zone"]
  end

  test "with three members the fair share is rounded (33) and the zone judges the exact share" do
    household, (a, b, c) = build_household("Alice", "Bob", "Chloé")
    # 43.2 % is out of 23-43 even though it is shown as 43 %.
    bulk_log!(household, a => 216, b => 142, c => 142)

    s = stats(household)
    assert_equal 33, s.fair_share
    assert_equal 43, s.member_for(a).mental_share
    assert_not s.member_for(a).in_zone
    assert s.member_for(b).in_zone
  end

  test "one dimension in the zone and the other out is unbalanced" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log_split!(household, alice => [ 1, 1 ], bob => [ 1, 4 ])

    s = stats(household)
    assert s.unbalanced?
    assert s.member_for(alice).in_zone_mental
    assert_not s.member_for(alice).in_zone_execution
  end

  test "a member with no log at all has 0 % and makes the week unbalanced" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log!(household, alice, at: @wednesday, count: 4)

    s = stats(household)
    assert s.unbalanced?
    assert_equal 0, s.member_for(bob).mental_share
    assert s.member_for(bob).empty?
  end

  test "three members: fair share 33, zone 23-43, both edges inclusive" do
    household, (a, b, c) = build_household("Alice", "Bob", "Chloé")
    # mental 3/13 = 23.1 %, 5/13 = 38.5 %; execution 3/7 = 42.9 %, 2/7 = 28.6 %
    log_split!(household, a => [ 3, 3 ], b => [ 5, 2 ], c => [ 5, 2 ])

    s = stats(household)
    assert_equal 33, s.fair_share
    assert_equal 23..43, s.zone
    assert_equal [ 23, 38, 38 ], s.members.map(&:mental_share)
    assert_equal [ 43, 29, 29 ], s.members.map(&:execution_share)
    assert s.balanced?
  end

  test "three members: 25/25/50 is unbalanced" do
    household, (a, b, c) = build_household("Alice", "Bob", "Chloé")
    log!(household, a, at: @wednesday)
    log!(household, b, at: @wednesday)
    log!(household, c, at: @wednesday, count: 2)

    assert stats(household).unbalanced?
  end

  test "fair share for each household size" do
    assert_nil WeeklyStats.fair_share_for(0)
    assert_equal [ 100, 50, 33, 25, 20, 17 ], (1..6).map { WeeklyStats.fair_share_for(_1) }
  end

  test "a single-member household is neutral" do
    household, (alice,) = build_household("Alice")
    log!(household, alice, at: @wednesday)

    s = stats(household)
    assert s.neutral?
    assert_equal :too_few_active_members, s.neutral_reason
    assert_equal 100, s.fair_share
  end

  test "a week without mental-load logs, or without execution logs, is neutral" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log!(household, alice, at: @wednesday, mental: false)
    log!(household, bob, at: @wednesday, mental: false)
    assert_equal :no_mental_logs, stats(household).neutral_reason

    ChoreLog.update_all(mental_load: true, execution_load: false)
    assert_equal :no_execution_logs, stats(household).neutral_reason

    ChoreLog.delete_all
    assert_equal :no_mental_logs, stats(household).neutral_reason
  end

  test "a paused member is not active: the fair share is recomputed on the others and their logs leave the shares" do
    household, (a, b, c) = build_household("Alice", "Bob", "Chloé")
    travel_to(paris(2026, 10, 5, 8)) { MemberPause.declare!(member: membership(household, c), declared_by: c, starts_on: Date.new(2026, 10, 5)) }
    log!(household, a, at: @wednesday, count: 2)
    log!(household, b, at: @wednesday, count: 2)
    log!(household, c, at: @wednesday, count: 5)

    s = stats(household)
    assert_equal 50, s.fair_share
    assert s.balanced?
    assert_equal 4, s.mental_total
    paused = s.member_for(c)
    assert paused.paused
    assert_nil paused.mental_share
    assert_not paused.in_zone
    assert_equal 5, paused.logs_count
    assert_equal 1, s.pauses.size
    assert_equal [ a.id, b.id ], s.active_members.map(&:user_id)
  end

  test "two members with one paused: neutral" do
    household, (alice, bob) = build_household("Alice", "Bob")
    travel_to(paris(2026, 10, 1, 8)) { MemberPause.declare!(member: membership(household, bob), declared_by: bob, starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 10, 5)) }
    log!(household, alice, at: @wednesday)

    s = stats(household)
    assert_equal :too_few_active_members, s.neutral_reason
    assert_equal 1, s.pauses.size, "a pause ending on Monday still overlaps the week"
  end

  test "a pause ending the Sunday before does not overlap the week" do
    household, (alice, bob) = build_household("Alice", "Bob")
    travel_to(paris(2026, 9, 28, 8)) { MemberPause.declare!(member: membership(household, bob), declared_by: bob, starts_on: Date.new(2026, 9, 28), ends_on: Date.new(2026, 10, 4)) }

    assert_empty stats(household).pauses
    assert_equal 2, stats(household).active_members.size
  end

  test "a member who joins during the week makes it neutral (the arrival week counts for nobody)" do
    household, (alice, bob) = build_household("Alice", "Bob")
    chloe = join(household, "Chloé", at: paris(2026, 10, 7, 9))
    [ alice, bob, chloe ].each { |u| log!(household, u, at: paris(2026, 10, 8, 9)) }

    s = stats(household)
    assert_equal :member_arrived, s.neutral_reason
    assert s.member_for(chloe).arrived
    assert_equal 33, s.fair_share
  end

  test "joining exactly at Monday 00:00 is not an arrival; joining after the week is not in it" do
    household, (alice, bob) = build_household("Alice", "Bob")
    household.household_members.where(user: bob).update_all(created_at: @week.start_at)
    join(household, "Chloé", at: paris(2026, 10, 12, 0, 0, 1))
    log_balanced_week!(household, [ alice, bob ], @week)

    s = stats(household)
    assert_equal 2, s.members.size
    assert_not s.member_for(bob).arrived
    assert s.balanced?
  end

  test "a member who left is not in the week and their logs leave the shares" do
    household, (alice, bob, chloe) = build_household("Alice", "Bob", "Chloé")
    log_balanced_week!(household, [ alice, bob ], @week)
    log!(household, chloe, at: @wednesday, count: 6)
    membership(household, chloe).leave!

    s = stats(household)
    assert_equal [ alice.id, bob.id ], s.members.map(&:user_id)
    assert s.balanced?
  end

  test "logs of a deleted chore and of a custom chore count; logs detached from the household do not" do
    household, (alice, bob) = build_household("Alice", "Bob")
    custom = household.chores.create!(custom_name: "Réparer la chaudière", category: "maintenance",
                                      mental_load: true, time_required: 30, assignee_user_ids: [ alice.id ])
    log!(household, alice, at: @wednesday, chore: custom)
    catalogue = household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ bob.id ])
    log!(household, bob, at: @wednesday, chore: catalogue)
    catalogue.destroy!
    ChoreLog.create!(user: bob, household: nil, chore_name: "Ailleurs", mental_load: true, execution_load: true, time_spent: 10, completed_at: @wednesday)

    s = stats(household)
    assert_equal [ 1, 1 ], s.members.map(&:logs_count)
    assert s.balanced?
  end

  test "another household's logs never count" do
    household, (alice, bob) = build_household("Alice", "Bob")
    other, (carol, _dave) = build_household("Carol", "Dave")
    log_balanced_week!(household, [ alice, bob ], @week)
    log!(other, carol, at: @wednesday, count: 5)

    assert_equal [ 1, 1 ], stats(household).members.map(&:logs_count)
  end

  test "Sunday 23:59:59 local is in the week, Monday 00:00 is in the next one" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log!(household, alice, at: paris(2026, 10, 11, 23, 59, 59))
    log!(household, bob, at: paris(2026, 10, 12, 0, 0, 0))

    assert_equal [ 1, 0 ], stats(household).members.map(&:logs_count)
    assert_equal [ 0, 1 ], stats(household, @week.next).members.map(&:logs_count)
  end

  test "weeks follow the household's zone, not UTC" do
    zone = "America/New_York"
    household, (alice, bob) = build_household("Alice", "Bob", zone: zone)
    week = Week.containing(Date.new(2026, 10, 5), zone)
    # Sunday 23:30 in New York is Monday 03:30 UTC.
    log!(household, alice, at: local(zone, 2026, 10, 11, 23, 30))
    log!(household, bob, at: local(zone, 2026, 10, 5, 0, 15))
    log!(household, bob, at: local(zone, 2026, 10, 4, 23, 45)) # previous week

    s = stats(household, week)
    assert_equal [ 1, 1 ], s.members.map(&:logs_count)
    assert_equal "America/New_York", s.to_snapshot[:time_zone]
  end

  test "the week of the autumn DST change keeps Sunday's late logs" do
    household, (alice, bob) = build_household("Alice", "Bob")
    week = Week.containing(Date.new(2026, 10, 19), PARIS) # clocks go back on Sun 25 Oct
    log!(household, alice, at: paris(2026, 10, 25, 23, 30)) # 22:30 UTC
    log!(household, bob, at: paris(2026, 10, 19, 0, 30))     # Sun 18 Oct 22:30 UTC

    assert_equal [ 1, 1 ], stats(household, week).members.map(&:logs_count)
    assert_equal 169.hours.to_i, (week.end_at - week.start_at).round
  end

  test "mental load by category, a missing category counted as other" do
    household, (alice, bob) = build_household("Alice", "Bob")
    log!(household, alice, at: @wednesday, category: "cooking", count: 2)
    log!(household, bob, at: @wednesday, category: nil)
    log!(household, bob, at: @wednesday, category: "cooking", mental: false)

    assert_equal({ "cooking" => 2, "other" => 1 }, stats(household).mental_by_category)
  end

  test "the snapshot carries first names and leaves the pause reason out" do
    household, (alice, bob) = build_household("Alice", "Bob")
    travel_to(paris(2026, 10, 5, 8)) { MemberPause.declare!(member: membership(household, bob), declared_by: bob, starts_on: Date.new(2026, 10, 6), reason: "Hôpital") }

    snapshot = stats(household).to_snapshot
    assert_equal Date.new(2026, 10, 5), snapshot[:week_start]
    assert_equal %w[Alice Bob], snapshot[:members].map { _1["first_name"] }
    assert_equal "Bob", snapshot[:pauses].first["first_name"]
    assert_equal bob.id, snapshot[:pauses].first["declared_by_id"]
    assert_not_includes snapshot.to_s, "Hôpital"
    assert_equal "neutral", snapshot[:outcome]
  end
end
