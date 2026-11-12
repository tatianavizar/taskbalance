# The planned split of one week: which chores, how many times each comes up
# that week, and who carries them. Read from the household's chores (the
# standing split, before a week plan exists) or from a WeekPlan's snapshot.
#
# The metric (backlog 2.2c, decisions of 2026-11-08):
#   - each chore weighs its planned occurrences in the week (daily = 7);
#   - a chore shared by several assignees counts in full for each of them;
#   - two shares per participant, mental and execution, each = their planned
#     occurrences on that load / everyone's, in %;
#   - the split shows one bar per participant: the average of the two.
# Shares stay unrounded here; screens round for display.
class PlannedSplit
  Item = Data.define(:chore_id, :name, :category, :frequency, :times_per_period, :occurrences,
                     :mental_load, :execution_load, :time_required, :assignees) do
    def self.from_chore(chore, week)
      new(chore_id: chore.id, name: chore.effective_name, category: chore.effective_category,
          frequency: chore.frequency, times_per_period: chore.times_per_period,
          occurrences: chore.occurrences_in(week), mental_load: chore.mental_load,
          execution_load: chore.execution_load, time_required: chore.effective_time_required,
          assignees: chore.assignee_keys)
    end

    def self.from_h(hash)
      hash = hash.symbolize_keys
      new(**members.index_with { |m| hash[m] }.merge(assignees: Array(hash[:assignees])))
    end

    def to_h
      super.transform_keys(&:to_s)
    end
  end

  Share = Data.define(:mental, :execution, :mental_count, :execution_count) do
    # One bar: the average of the two charges. A charge nobody plans this
    # week (no occurrence) is left out of the average.
    def average
      values = [ mental, execution ].compact
      values.empty? ? nil : values.sum / values.size
    end
  end

  attr_reader :items, :participants, :week

  # The standing split of the household's active chores.
  def self.from_household(household, week: household.current_week, participants: household.split_participants)
    chores = household.chores.active.includes(:task, :chore_assignees).order(:id)
    new(items: chores.map { |chore| Item.from_chore(chore, week) }, participants: participants, week: week)
  end

  def initialize(items:, participants:, week:)
    @items = items
    @participants = participants
    @week = week
  end

  def participant_keys
    participants.map(&:key)
  end

  # { participant key => Share }
  def shares
    @shares ||= self.class.shares_for(items, participant_keys)
  end

  def share_of(key)
    shares[key]
  end

  # Fair share for this split, unrounded (100 / participants).
  def fair_share
    participants.empty? ? nil : 100.0 / participants.size
  end

  # True when every participant's bar rounds to the fair share: the split is
  # "50/50 pile". Otherwise screens say the real gap will be carried over.
  def exact?
    fair = HouseholdRules.fair_share(participants.size)
    return true if fair.nil?

    shares.values.all? { |share| share.average.nil? || share.average.round == fair }
  end

  def items_by_category
    items.group_by(&:category)
  end

  # { participant key => Share } for plain items (anything responding to
  # occurrences, mental_load, execution_load and assignees).
  def self.shares_for(items, keys)
    mental = keys.index_with(0)
    execution = keys.index_with(0)
    items.each do |item|
      (Array(item.assignees) & keys).each do |key|
        mental[key] += item.occurrences if item.mental_load
        execution[key] += item.occurrences if item.execution_load
      end
    end
    mental_total = mental.values.sum
    execution_total = execution.values.sum
    keys.index_with do |key|
      Share.new(
        mental: mental_total.zero? ? nil : 100.0 * mental[key] / mental_total,
        execution: execution_total.zero? ? nil : 100.0 * execution[key] / execution_total,
        mental_count: mental[key], execution_count: execution[key]
      )
    end
  end
end
