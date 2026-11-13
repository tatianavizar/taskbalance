# What the home shows (D1, D2, D8, D12) for one person of a household, on the
# current local week. Every figure comes from WeeklyStats, the single source:
# nothing is counted here.
#
#   home = HomeSummary.new(household: household, viewer: user)
#   home.week                  # => Week
#   home.stats                 # => WeeklyStats
#   home.status                # => nil (in progress), :provisional or :final
#                              #    from the stored HouseholdWeek of the week
#   home.empty?                # nothing logged yet this week (D1)
#   home.headline              # => Headline or nil
#   home.balance(:mental)      # => Balance: the viewer's share, the others', the zone
#   home.level / balanced_weeks / next_threshold   # the household's progress
#   home.arrived_members       # who joined this week (the week does not count)
#   home.planned_for_viewer    # tasks of the validated split carried by the viewer
class HomeSummary
  DIMENSIONS = %i[mental execution].freeze

  # `member`: the one who carries the most above the zone (else the one the
  # furthest from it); `share`: their percentage.
  Headline = Data.define(:dimension, :kind, :member, :share, :zone)

  Balance = Data.define(:dimension, :share, :count, :total, :in_zone, :others, :fair, :zone) do
    def measured? = !share.nil?
  end

  attr_reader :household, :viewer, :week, :stats

  def initialize(household:, viewer:, week: household.current_week)
    @household = household
    @viewer = viewer
    @week = week
    @stats = WeeklyStats.new(household, week)
  end

  def viewer_member
    stats.member_for(viewer)
  end

  def status
    stored_week&.status&.to_sym
  end

  # Nothing was logged by anyone this week.
  def empty?
    stats.members.sum(&:logs_count).zero?
  end

  def arrived_members
    stats.members.select(&:arrived)
  end

  def viewer_arrived?
    viewer_member&.arrived == true
  end

  # The first week that counts for a person who arrived during this one.
  def first_counting_week
    week.next
  end

  def balance(dimension)
    dimension = dimension.to_sym
    me = viewer_member
    total = total_of(dimension)
    others = stats.active_members.reject { |member| member.user_id == viewer.id }.map do |member|
      { name: member.first_name, share: share_of(member, dimension), balanced: in_zone?(member, dimension) }
    end
    Balance.new(dimension: dimension, share: me && share_of(me, dimension), count: me && count_of(me, dimension),
                total: total, in_zone: me.present? && in_zone?(me, dimension), others: others,
                fair: stats.fair_share, zone: stats.zone)
  end

  # The sentence on top of the home. It names who carries more when the week
  # is out of the zone, and nobody when it is not (nothing to blame).
  def headline
    return @headline if defined?(@headline)

    @headline = build_headline
  end

  # Names, from the highest share down, of the people out of the zone.
  def out_of_zone(dimension)
    return [] if total_of(dimension).zero?

    stats.active_members.reject { |m| in_zone?(m, dimension) }
      .sort_by { |m| -(exact_of(m, dimension) || 0) }
  end

  def level = household.level

  def balanced_weeks = household.balanced_weeks_count

  def ultimate? = level >= Progression::ULTIMATE

  # Balanced weeks needed for the next level, nil at the ultimate one.
  def next_threshold
    ultimate? ? nil : Progression.threshold(level + 1)
  end

  # Tasks of the validated split the viewer carries this week (D12).
  def planned_for_viewer
    plan = household.week_plan_for(week)
    return unless plan

    key = "user:#{viewer.id}"
    plan.assignments.count { |item| Array(item["assignees"]).include?(key) }
  end

  private

  def stored_week
    return @stored_week if defined?(@stored_week)

    @stored_week = household.household_weeks.find_by(week_start: week.monday)
  end

  def build_headline
    return if empty?

    reason = stats.neutral_reason
    return if reason == :too_few_active_members || stats.zone.nil?

    worst = DIMENSIONS.filter_map { |dimension| worst_of(dimension) }.max_by { |h| h[:gap] }
    if worst
      Headline.new(dimension: worst[:dimension], kind: worst[:above] ? :above : :below,
                   member: worst[:member], share: worst[:member_share], zone: stats.zone)
    elsif stats.balanced?
      Headline.new(dimension: nil, kind: :balanced, member: nil, share: nil, zone: stats.zone)
    end
  end

  # The person the furthest out of the zone in a dimension, above it first.
  def worst_of(dimension)
    out = out_of_zone(dimension)
    return if out.empty?

    zone = stats.zone
    scored = out.map do |member|
      exact = exact_of(member, dimension)
      above = exact > zone.end
      { member: member, member_share: share_of(member, dimension), dimension: dimension, above: above,
        gap: above ? exact - zone.end : zone.begin - exact }
    end
    scored.max_by { |item| [ item[:above] ? 1 : 0, item[:gap] ] }
  end

  def total_of(dimension)
    dimension == :mental ? stats.mental_total : stats.execution_total
  end

  def share_of(member, dimension)
    dimension == :mental ? member.mental_share : member.execution_share
  end

  def exact_of(member, dimension)
    dimension == :mental ? member.mental_share_exact : member.execution_share_exact
  end

  def count_of(member, dimension)
    dimension == :mental ? member.mental_count : member.execution_count
  end

  def in_zone?(member, dimension)
    dimension == :mental ? member.in_zone_mental : member.in_zone_execution
  end
end
