# The weekly report as the Bilan tab shows it (E1, E2, E7, E10, E14), for one
# household and one local week. One reader for every state of a week:
#
# - the current week is read live from WeeklyStats (never stored yet, or only
#   as a provisional row that the next edit would make stale);
# - a past week is read from its HouseholdWeek snapshot, provisional or final,
#   so a late log never rewrites what was closed. A past week with no stored
#   row (the engine has not run yet) falls back on WeeklyStats and is shown
#   as provisional.
#
#   report = WeekReport.for(household, week)
#   report.status                 # => :provisional or :final
#   report.final? / provisional?
#   report.final_at               # Monday 03:00 after the week, household zone
#   report.outcome                # => :balanced / :unbalanced / :neutral (D3 correction applied)
#   report.neutral_reason         # => :too_few_active_members, :member_arrived,
#                                 #    :no_mental_logs, :no_execution_logs, :pause_declared
#   report.corrected?             # a retroactive pause turned the week neutral (D3)
#   report.corrections            # [WeekCorrection], « Neutre · pause déclarée le … »
#   report.original_outcome       # what the stored report says, never rewritten
#   report.lines / active_lines   # [WeekReport::Line] per member
#   report.line_for(user)
#   report.total(:mental)         # active members' logs of that dimension
#   report.share(line, :mental)   # rounded % of the active total, for display
#   report.in_zone?(line, :mental)
#   report.fair_share / zone
#   report.headline               # who carries more, or nil
#   report.lesson                 # the E1 educational card, or nil
#   report.shift_to_zone(line, :mental) # tasks the carrier would have had to leave to others
#   report.minutes_total / minutes_share(line)
#   report.pauses                 # [WeekReport::Pause], dates only: the reason is private
#   report.level_changes          # level moves this week's final report caused
class WeekReport
  DIMENSIONS = %i[mental execution].freeze

  Line = Data.define(
    :user_id, :first_name, :color, :monogram, :mental_count, :execution_count, :minutes, :logs_count,
    :mental_share, :execution_share, :mental_share_exact, :execution_share_exact,
    :paused, :in_zone_mental, :in_zone_execution
  ) do
    def count(dimension) = dimension == :mental ? mental_count : execution_count
    def share(dimension) = dimension == :mental ? mental_share : execution_share
    def exact(dimension) = dimension == :mental ? mental_share_exact : execution_share_exact
    def in_zone(dimension) = dimension == :mental ? in_zone_mental : in_zone_execution
    def active? = !paused
  end

  Pause = Data.define(:user_id, :first_name, :starts_on, :ends_on, :declared_by_id)

  # `member`: the one who carries the most above the zone (else the one the
  # furthest below it). kind: :above or :below.
  Headline = Data.define(:dimension, :kind, :member, :share)

  # E1's educational card: one charge is in the zone for everyone, the other
  # is not. `carrier` is the person above the zone on `off`, `shift` the
  # number of their tasks that would have had to go to others.
  Lesson = Data.define(:in_zone, :off, :carrier, :shift, :count, :total, :others)

  attr_reader :household, :week, :record

  def self.for(household, week)
    stored = household.household_weeks.includes(:week_corrections).find_by(week_start: week.monday)
    return from_record(household, stored) if stored && week.monday != household.current_week.monday

    from_stats(household, week, record: stored)
  end

  def self.from_record(household, record)
    new(household: household, week: record.week, record: record, status: record.status.to_sym,
        data: record.slice(*DATA_KEYS).as_json)
  end

  def self.from_stats(household, week, record: nil)
    data = WeeklyStats.new(household, week).to_snapshot.as_json.slice(*DATA_KEYS)
    new(household: household, week: week, record: record, status: :provisional, data: data)
  end

  DATA_KEYS = %w[outcome neutral_reason fair_share mental_total execution_total minutes_total members pauses].freeze

  def initialize(household:, week:, data:, status:, record: nil)
    @household = household
    @week = week
    @record = record
    @status = status
    @data = data.with_indifferent_access
  end

  attr_reader :status

  def final? = status == :final
  def provisional? = status == :provisional

  def final_at
    HouseholdWeek.final_at(week)
  end

  # ---- outcome ---------------------------------------------------------------

  def corrections
    @corrections ||= record&.week_corrections&.to_a || []
  end

  def corrected? = corrections.any?

  def original_outcome = @data[:outcome].to_sym

  def outcome = corrected? ? :neutral : original_outcome

  def neutral_reason
    return WeekCorrection::NEUTRAL_REASON.to_sym if corrected?

    @data[:neutral_reason]&.to_sym
  end

  def balanced? = outcome == :balanced
  def unbalanced? = outcome == :unbalanced
  def neutral? = outcome == :neutral

  # Nobody logged anything that week.
  def silent?
    lines.sum(&:logs_count).zero?
  end

  # ---- people and figures -----------------------------------------------------

  def lines
    @lines ||= Array(@data[:members]).map do |m|
      Line.new(user_id: m[:user_id], first_name: m[:first_name], color: m[:color], monogram: m[:monogram],
               mental_count: m[:mental_count].to_i, execution_count: m[:execution_count].to_i,
               minutes: m[:minutes].to_i, logs_count: m[:logs_count].to_i,
               mental_share: m[:mental_share], execution_share: m[:execution_share],
               mental_share_exact: m[:mental_share_exact], execution_share_exact: m[:execution_share_exact],
               paused: m[:paused] == true, in_zone_mental: m[:in_zone_mental] == true,
               in_zone_execution: m[:in_zone_execution] == true)
    end
  end

  def active_lines = lines.select(&:active?)

  def line_for(user)
    id = user.respond_to?(:id) ? user.id : user
    lines.find { |line| line.user_id == id }
  end

  def fair_share = @data[:fair_share]

  def zone
    fair_share && ((fair_share - HouseholdRules::ZONE)..(fair_share + HouseholdRules::ZONE))
  end

  def total(dimension)
    dimension == :mental ? @data[:mental_total].to_i : @data[:execution_total].to_i
  end

  def share(line, dimension) = line.share(dimension)

  def in_zone?(line, dimension) = line.in_zone(dimension)

  def minutes_total = @data[:minutes_total].to_i

  def minutes_share(line)
    return nil if minutes_total.zero? || line.paused

    (line.minutes * 100r / minutes_total).round
  end

  # Active members out of the zone on a dimension, the highest share first.
  def out_of_zone(dimension)
    return [] if total(dimension).zero?

    active_lines.reject { |line| line.in_zone(dimension) }.sort_by { |line| -(line.exact(dimension) || 0) }
  end

  # ---- what to read in it ------------------------------------------------------

  def headline
    return @headline if defined?(@headline)

    @headline = unbalanced? ? build_headline : nil
  end

  def lesson
    return @lesson if defined?(@lesson)

    @lesson = unbalanced? ? build_lesson : nil
  end

  # Tasks of `line` on `dimension` that others would have had to do for `line`
  # to land at the top of the zone. The total does not move: the task is
  # still done, by someone else.
  def shift_to_zone(line, dimension)
    top = zone&.end
    return 0 if top.nil? || total(dimension).zero?

    [ (line.count(dimension) - Rational(top * total(dimension), 100)).ceil, 0 ].max
  end

  # ---- pauses, level -----------------------------------------------------------

  def pauses
    @pauses ||= Array(@data[:pauses]).map do |p|
      Pause.new(user_id: p[:user_id], first_name: p[:first_name], starts_on: Date.iso8601(p[:starts_on]),
                ends_on: (Date.iso8601(p[:ends_on]) if p[:ends_on].present?), declared_by_id: p[:declared_by_id])
    end
  end

  def declarer_name(pause)
    return nil if pause.declared_by_id.nil?

    User.find_by(id: pause.declared_by_id)&.first_name
  end

  # What this week's closing did to the level (E8, E13). Nothing for a
  # provisional week.
  def level_changes
    return LevelChange.none unless final?

    household.level_changes.where(week_start: week.monday, reason: %w[reached ultimate_lost ultimate_regained])
      .chronological
  end

  private

  def build_headline
    candidates = DIMENSIONS.filter_map do |dimension|
      out = out_of_zone(dimension)
      next if out.empty?

      member = out.first
      above = zone && member.exact(dimension) > zone.end
      gap = above ? member.exact(dimension) - zone.end : zone.begin - member.exact(dimension)
      { dimension: dimension, member: member, above: above, gap: gap }
    end
    worst = candidates.max_by { |c| [ c[:above] ? 1 : 0, c[:gap] ] }
    return unless worst

    Headline.new(dimension: worst[:dimension], kind: (worst[:above] ? :above : :below),
                 member: worst[:member], share: worst[:member].share(worst[:dimension]))
  end

  def build_lesson
    off = DIMENSIONS.select { |dimension| out_of_zone(dimension).any? }
    return unless off.size == 1

    dimension = off.first
    in_zone_dimension = (DIMENSIONS - off).first
    return if total(in_zone_dimension).zero?

    carrier = out_of_zone(dimension).find { |line| zone && line.exact(dimension) > zone.end }
    return unless carrier

    Lesson.new(in_zone: in_zone_dimension, off: dimension, carrier: carrier, shift: shift_to_zone(carrier, dimension),
               count: carrier.count(dimension), total: total(dimension),
               others: active_lines.reject { |line| line.user_id == carrier.user_id })
  end
end
