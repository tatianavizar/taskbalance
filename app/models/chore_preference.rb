# What one person thinks of one household chore: J'aime, Neutre or Je n'aime
# pas (B10, C3, P7). No row means Neutre.
#
# Private to its author: screens only ever read the current user's own rows.
# The split proposal (SplitProposal) reads everyone's, and shows none of them.
class ChorePreference < ApplicationRecord
  CHOICES = %w[like neutral dislike].freeze

  belongs_to :user
  belongs_to :chore

  enum :choice, CHOICES.index_by(&:itself), validate: true

  validates :chore_id, uniqueness: { scope: :user_id }

  # The author's choices for the given chores, as { chore_id => "like" }.
  # Missing chores are neutral.
  def self.choices_for(user, chores)
    where(user: user, chore_id: chores.map { |c| c.respond_to?(:id) ? c.id : c }).pluck(:chore_id, :choice).to_h
  end

  # Records `person`'s choices, { chore_id => choice }, for chores of
  # `household` only. `person` is the acting user: a member, or (lot 3) an
  # invited person before they join. Returns false and writes nothing when a
  # chore is not the household's or a choice is unknown.
  def self.record!(person, household, choices)
    choices = choices.to_h.transform_keys(&:to_i).transform_values(&:to_s)
    allowed = household.chores.active.where(id: choices.keys).pluck(:id)
    return false unless (choices.keys - allowed).empty? && choices.values.all? { |c| CHOICES.include?(c) }

    transaction do
      choices.each do |chore_id, choice|
        record = find_or_initialize_by(user_id: person.id, chore_id: chore_id)
        record.update!(choice: choice)
      end
    end
    true
  end
end
