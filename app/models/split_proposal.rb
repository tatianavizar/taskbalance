# Proposes who carries which chore (decision D18). Simple and deterministic:
# the same chores, people and preferences always give the same split.
#
# 1. Preferences first. Chores are taken heaviest first (planned occurrences,
#    then id). A chore someone likes goes to whoever likes it; a chore
#    nobody likes goes to someone who does not dislike it; if everyone
#    dislikes it, anyone can take it. Among those candidates, it goes to the
#    one it brings closest to their target share.
# 2. Then balance. A chore moves from one person to another as long as the
#    move brings the planned shares closer to the targets. A chore never
#    moves to someone who dislikes it (unless its holder dislikes it too),
#    and a chore its holder likes only moves when no other move helps.
#
# "Closer" is measured on both charges: the sum, over participants, of the
# squared gaps between their mental share and their target, and between their
# execution share and their target. Planned occurrences make the shares (see
# PlannedSplit).
#
# Inputs
#   items        anything with id/chore_id, occurrences, mental_load,
#                execution_load (PlannedSplit::Item, or SplitProposal::Item)
#   participant_keys   in display order; it breaks ties
#   preferences  { key => { chore_id => "like" | "neutral" | "dislike" } }
#   fixed        { chore_id => [keys] } kept as they are (shared chores,
#                manual edits); they count in the loads
#   targets      { key => % } defaults to the fair share. Lot 6 passes
#                compensated targets to carry over last week's gap.
#
# Output: { chore_id => [keys] } for every item, fixed ones included.
class SplitProposal
  Item = Data.define(:chore_id, :occurrences, :mental_load, :execution_load)

  RANK = { "like" => 2, "neutral" => 1, "dislike" => 0 }.freeze
  EPSILON = 1e-9

  # Proposal for the household's active chores, from its members' (and
  # invited people's) preferences. `keep`: chore ids whose current assignees
  # stay as they are.
  def self.for_household(household, participants: household.split_participants, week: household.current_week,
                         keep: [], targets: nil)
    split = PlannedSplit.from_household(household, week: week, participants: participants)
    user_ids = participants.filter_map(&:user_id)
    by_user = ChorePreference.where(user_id: user_ids, chore_id: split.items.map(&:chore_id))
                             .pluck(:user_id, :chore_id, :choice)
                             .group_by(&:first)
    preferences = participants.to_h do |participant|
      rows = by_user.fetch(participant.user_id, [])
      [ participant.key, rows.to_h { |_, chore_id, choice| [ chore_id, choice ] } ]
    end
    keep = keep.to_set
    fixed = split.items.select { |item| keep.include?(item.chore_id) && item.assignees.any? }
                 .to_h { |item| [ item.chore_id, item.assignees & split.participant_keys ] }
                 .reject { |_, keys| keys.empty? }
    new(items: split.items, participant_keys: split.participant_keys, preferences: preferences,
        fixed: fixed, targets: targets).call
  end

  def initialize(items:, participant_keys:, preferences: {}, fixed: {}, targets: nil)
    @items = items.sort_by { |item| [ -weight(item), item_id(item) ] }
    @keys = participant_keys
    @preferences = preferences
    @fixed = fixed.transform_values { |keys| Array(keys) & participant_keys }
    @targets = targets || participant_keys.index_with { participant_keys.empty? ? 0 : 100.0 / participant_keys.size }
  end

  def call
    return {} if @keys.empty?

    @owner = {}
    @mental = @keys.index_with(0)
    @execution = @keys.index_with(0)
    @count = @keys.index_with(0)
    @fixed.each { |chore_id, keys| keys.each { |key| add(item_by_id(chore_id), key) } if item_by_id(chore_id) }

    free_items.each { |item| place(item) }
    balance

    @items.to_h { |item| [ item_id(item), @fixed[item_id(item)] || [ @owner[item_id(item)] ] ] }
  end

  private

  def free_items
    @items.reject { |item| @fixed.key?(item_id(item)) }
  end

  def item_by_id(chore_id)
    @items_by_id ||= @items.index_by { |item| item_id(item) }
    @items_by_id[chore_id]
  end

  def item_id(item)
    item.respond_to?(:chore_id) ? item.chore_id : item.id
  end

  def weight(item)
    item.occurrences * ((item.mental_load ? 1 : 0) + (item.execution_load ? 1 : 0))
  end

  def rank(key, item)
    RANK.fetch(@preferences.dig(key, item_id(item)).to_s, 1)
  end

  # Step 1.
  def place(item)
    likers = @keys.select { |key| rank(key, item) == 2 }
    candidates = likers.presence || @keys.select { |key| rank(key, item) >= 1 }.presence || @keys
    best = candidates.min_by.with_index do |key, index|
      add(item, key)
      score = [ objective, @count[key], index ]
      remove(item, key)
      score
    end
    add(item, best)
    @owner[item_id(item)] = best
  end

  # Step 2: best single move, first among chores whose holder does not like
  # them, then among liked ones. Stops when no move helps.
  def balance
    (@items.size * @keys.size * 2).times do
      move = best_move(liked: false) || best_move(liked: true)
      break unless move

      item, from, to = move
      remove(item, from)
      add(item, to)
      @owner[item_id(item)] = to
    end
  end

  def best_move(liked:)
    current = objective
    best = nil
    best_score = current - EPSILON
    free_items.each do |item|
      from = @owner[item_id(item)]
      next if (rank(from, item) == 2) != liked

      @keys.each do |to|
        next if to == from
        next if rank(to, item).zero? && !rank(from, item).zero?

        remove(item, from)
        add(item, to)
        score = objective
        remove(item, to)
        add(item, from)
        if score < best_score
          best_score = score
          best = [ item, from, to ]
        end
      end
    end
    best
  end

  def add(item, key)
    @mental[key] += item.occurrences if item.mental_load
    @execution[key] += item.occurrences if item.execution_load
    @count[key] += 1
  end

  def remove(item, key)
    @mental[key] -= item.occurrences if item.mental_load
    @execution[key] -= item.occurrences if item.execution_load
    @count[key] -= 1
  end

  def objective
    gap(@mental) + gap(@execution)
  end

  def gap(counts)
    total = counts.values.sum
    return 0.0 if total.zero?

    counts.sum { |key, count| ((100.0 * count / total) - @targets.fetch(key, 0)) ** 2 }
  end
end
