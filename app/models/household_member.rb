class HouseholdMember < ApplicationRecord
  # Palette offered to members, in the order it is handed out. The colour is
  # unique inside a household, so a household holds at most COLORS.size people.
  COLORS = %w[mint blue stone sky sage sand].freeze
  MONOGRAM_MAX_LENGTH = 2

  belongs_to :user
  belongs_to :household
  has_many :member_pauses, dependent: :delete_all
  has_many :absence_inquiries, dependent: :delete_all

  enum :role, { member: 0, manager: 1 }, default: :member

  attr_accessor :email

  validates :user_id, presence: true
  validates :household_id, presence: true
  # One household per account (decision of 2026-11-08).
  validates :user_id, uniqueness: { message: :already_in_a_household }
  validates :color, presence: true, inclusion: { in: COLORS, allow_blank: true },
                    uniqueness: { scope: :household_id, allow_blank: true }
  validates :monogram, presence: true, length: { maximum: MONOGRAM_MAX_LENGTH }
  validate :household_not_full, on: :create

  before_validation :assign_color, on: :create
  before_validation :assign_monogram, on: :create
  before_validation :normalise_monogram
  after_create :refresh_household_monograms
  after_create :refresh_household_state
  after_destroy :refresh_household_state

  # Colours still free in this household, in palette order.
  def available_colors
    COLORS - household.household_members.where.not(id: id).pluck(:color)
  end

  # Writes a monogram by hand: it stops being recomputed when people arrive.
  def customize_monogram!(value)
    update!(monogram: value, monogram_customized: true)
  end

  # Gives the automatic monogram back.
  def reset_monogram!
    update!(monogram_customized: false)
    self.class.refresh_monograms!(household)
    reload
  end

  # The person leaves the household (F2): chores handed over, week plans
  # updated, logs detached but kept, manager role passed to the oldest
  # remaining member; the last one out deletes the household. All the rules
  # are in HouseholdDeparture. Returns the new manager's membership, or nil.
  def leave!
    HouseholdDeparture.call(self)
  end

  # Recomputes the automatic monograms of a household: the first-name initial,
  # and initial + a letter of the name (the last one first) only for people
  # whose initial is shared with someone else. Hand-edited monograms are kept.
  def self.refresh_monograms!(household)
    members = household.household_members.includes(:user).order(:created_at, :id).to_a
    initial_of = ->(m) { m.monogram_customized? ? m.monogram.to_s[0].to_s.upcase : m.initial }
    initials = members.map(&initial_of)
    taken = members.select(&:monogram_customized?).map(&:monogram)

    members.each do |member|
      next if member.monogram_customized?

      initial = initial_of.(member)
      monogram = initial
      if initials.count(initial) > 1
        candidates = member.name_letters[1..].to_a.reverse.map { |c| initial + c.downcase }
        monogram = candidates.find { |c| taken.exclude?(c) } || candidates.first || initial
      end
      taken << monogram
      member.update_column(:monogram, monogram) if member.monogram != monogram
    end
  end

  def initial
    name_letters.first.to_s.upcase
  end

  def name_letters
    user.first_name.to_s.strip.chars
  end

  private

  def assign_color
    self.color = available_colors.first if color.blank? && household
  end

  # Provisional value so validation passes; the real one is computed once the
  # row exists (see refresh_household_monograms).
  def assign_monogram
    self.monogram = initial if monogram.blank? && user
  end

  def normalise_monogram
    self.monogram = monogram.to_s.strip.presence
  end

  def household_not_full
    return unless household && household.household_members.count >= COLORS.size

    errors.add(:base, :household_full)
  end

  # Arrival or departure (create, destroy, leave!): state solo/active and the
  # progression reset. Skipped when the whole household is being destroyed.
  def refresh_household_state
    return if destroyed_by_association

    household = Household.find_by(id: household_id) or return
    household.reset_progression_for_membership_change!
    household.refresh_membership_state!
  end

  def refresh_household_monograms
    self.class.refresh_monograms!(household)
    reload
  end
end
