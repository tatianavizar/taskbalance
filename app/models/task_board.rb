# What the Tasks tab lists (D3, D4) for one person of a household: the open
# occurrences of the week, in three sections.
#
#   late    due before today, of this week or an earlier one. Nothing lapses:
#           a task nobody did stays late until it is done, whatever its
#           frequency. `late_groups` folds them by chore, with a count, so a
#           daily task missed for a week is one line, not seven.
#   today   due today
#   later   due after today, until Sunday
#
# An occurrence is open while at least one person carrying it has not done
# it. « Fait » is offered to a person who carries it and has not done it
# (`can_complete?`). Someone else's task is listed, without the button.
#
#   board = TaskBoard.new(user: user, scope: :mine, category: "cooking")
#   board.late / board.due_today / board.later  # => [TaskBoard::Entry]
#   board.counts                              # => { all: 6, mine: 3, shared: 1 }
#   board.next_for_user                       # the next open task of the person
class TaskBoard
  SCOPES = %i[all mine shared].freeze

  Entry = Data.define(:occurrence, :chore, :assignees, :done_by_ids, :viewer_key) do
    def due_on = occurrence.due_on
    def name = chore.effective_name
    def category = chore.effective_category
    def assignee_keys = assignees.map(&:key)
    def shared? = assignees.size > 1
    def mine? = assignee_keys.include?(viewer_key)
    def done_by_viewer? = done_by_ids.include?(viewer_key.delete_prefix("user:").to_i)
    def can_complete? = mine? && !done_by_viewer?
    def loads = [ ("mental" if chore.mental_load), ("execution" if chore.execution_load) ].compact
    def minutes = chore.effective_time_required
  end

  attr_reader :user, :household, :scope, :category, :today

  def initialize(user:, scope: :all, category: nil)
    @user = user
    @household = user.household
    @scope = SCOPES.include?(scope.to_s.to_sym) ? scope.to_s.to_sym : :all
    @category = Chore::CATEGORIES.include?(category.to_s) ? category.to_s : nil
    @today = household.today
  end

  def late = visible.select { |entry| entry.due_on < today }
  # Late occurrences folded by chore, oldest first: one Group per chore.
  # `entry` is the one « Fait » fulfils: the oldest the viewer can do, else
  # the oldest.
  Group = Data.define(:chore, :entries) do
    def count = entries.size
    def oldest = entries.first
    def entry = entries.find(&:can_complete?) || oldest
    def since = oldest.due_on
  end

  def late_groups
    late.group_by { |entry| entry.chore.id }.values.map { |list| Group.new(chore: list.first.chore, entries: list) }
      .sort_by { |group| [ group.since, group.chore.effective_name.to_s ] }
  end

  def due_today = visible.select { |entry| entry.due_on == today }
  def later = visible.select { |entry| entry.due_on > today }

  def empty?
    visible.empty?
  end

  # The numbers on the filter chips, for the chosen category.
  def counts
    {
      all: in_category.size,
      mine: in_category.count(&:mine?),
      shared: in_category.count(&:shared?)
    }
  end

  # D4: what comes next for the person when nothing is due today.
  def next_for_user
    in_category.select { |entry| entry.mine? && !entry.done_by_viewer? && entry.due_on > today }.min_by(&:due_on)
  end

  # Categories present among the open tasks, for the filter.
  def categories
    entries.map(&:category).compact.uniq.sort_by { |c| Chore::CATEGORIES.index(c) || Chore::CATEGORIES.size }
  end

  private

  def visible
    @visible ||= in_category.select do |entry|
      case scope
      when :mine then entry.mine?
      when :shared then entry.shared?
      else true
      end
    end
  end

  def in_category
    @in_category ||= category ? entries.select { |entry| entry.category == category } : entries
  end

  def entries
    @entries ||= build_entries.sort_by { |entry| [ entry.due_on, entry.name.to_s ] }
  end

  def build_entries
    return [] unless household

    week = household.current_week
    participants = household.split_participants.index_by(&:key)
    viewer_key = "user:#{user.id}"

    current = ChoreOccurrence.of_active_chores.where(household_id: household.id).in_week(week)
    occurrences = ChoreOccurrence.where(id: current.select(:id))
      .or(ChoreOccurrence.where(id: ChoreOccurrence.earlier_weeks(household, week).select(:id)))
      .includes(:chore_logs, chore: [ :task, :chore_assignees ])

    occurrences.filter_map do |occurrence|
      keys = occurrence.chore.assignee_keys
      assignees = keys.filter_map { |key| participants[key] }
      done = occurrence.done_by_ids
      # Open while someone carrying it has not done it.
      pending = assignees.reject { |participant| participant.user_id && done.include?(participant.user_id) }
      next if assignees.empty? || pending.empty?

      Entry.new(occurrence: occurrence, chore: occurrence.chore, assignees: assignees, done_by_ids: done, viewer_key: viewer_key)
    end
  end
end
