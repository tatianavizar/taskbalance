# A task of the household: taken from the catalogue (task_id set) or written
# by a member (task_id nil, a "custom chore" with custom_name and category).
#
# It says how often it comes back (Recurrence), which loads it carries, how
# long it takes and who carries it (chore_assignees: one row per assignee,
# each carrying it in full, decision D6). Any member can add, edit and delete
# it (decision D14). A catalogue chore is retired (active: false) rather than
# deleted, so it can be ticked again; a custom chore is deleted. Either way
# its logs stay with their authors.
class Chore < ApplicationRecord
  include Recurrence

  CATEGORIES = %w[cooking groceries cleaning laundry childcare admin maintenance other].freeze
  CUSTOM_NAME_MAX_LENGTH = 80
  MAX_TIME_REQUIRED = 24 * 60

  belongs_to :household
  belongs_to :task, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :recurring_chore, optional: true
  # Logs outlive their chore: they belong to the user, not the household.
  has_many :chore_logs, dependent: :nullify
  has_many :chore_assignees, -> { order(:id) }, dependent: :delete_all, autosave: true, inverse_of: :chore
  has_many :assigned_users, through: :chore_assignees, source: :user
  has_many :chore_preferences, dependent: :delete_all

  enum :status, { pending: 0, in_progress: 1, completed: 2 }

  scope :active, -> { where(active: true) }
  scope :retired, -> { where(active: false) }
  scope :catalogue, -> { where.not(task_id: nil) }
  scope :custom, -> { where(task_id: nil) }

  before_validation :normalise_custom_name
  before_validation :take_task_loads, if: :catalogue_chore?
  before_validation :default_anchor

  validates :household_id, presence: true
  validates :custom_name, length: { maximum: CUSTOM_NAME_MAX_LENGTH }
  validates :category, inclusion: { in: CATEGORIES }, if: :custom_chore?
  validates :time_required, numericality: { only_integer: true, greater_than_or_equal_to: 1,
                                            less_than_or_equal_to: MAX_TIME_REQUIRED, allow_nil: true }
  validates :time_required, presence: true, if: :custom_chore?
  validate :custom_name_present
  validate :at_least_one_load
  validate :at_least_one_assignee
  validate :assignees_belong_to_household

  def catalogue_chore?
    task_id.present?
  end

  def custom_chore?
    task_id.nil?
  end

  def effective_name
    task&.name || custom_name
  end

  def effective_category
    task&.category || category
  end

  def effective_time_required
    time_required || task&.time_required
  end

  # Planned occurrences in a week (Week). The weight of the chore in the split.
  def occurrences_in(week)
    Recurrence.occurrences(frequency: frequency, times_per_period: times_per_period,
                           anchor_on: anchor_on, week: week)
  end

  # --- Assignees ----------------------------------------------------------
  # An assignee is named by a participant key (SplitParticipant): "user:12"
  # for a member, "invitation:5" for someone invited but not yet in.

  def assignee_keys
    chore_assignees.reject(&:marked_for_destruction?).map(&:participant_key)
  end

  # Replaces the assignees. Unknown keys are rejected at validation.
  def assignee_keys=(keys)
    wanted = Array(keys).map(&:to_s).compact_blank.uniq
    chore_assignees.each { |assignee| assignee.mark_for_destruction unless wanted.include?(assignee.participant_key) }
    present = chore_assignees.map(&:participant_key)
    (wanted - present).each do |key|
      attributes = ChoreAssignee.attributes_for(key)
      attributes ? chore_assignees.build(attributes) : (@invalid_assignee_keys ||= []) << key
    end
  end

  # Shorthand for members only.
  def assignee_user_ids=(ids)
    self.assignee_keys = Array(ids).compact_blank.map { |id| "user:#{id.to_i}" }
  end

  # Virtual attributes the validations report on (C6 shows one message under
  # the two load boxes, one under the assignees).
  def loads
    [ ("mental" if mental_load), ("execution" if execution_load) ].compact
  end

  def assignees
    assignee_keys
  end

  def assigned_to?(user)
    assignee_keys.include?("user:#{user.id}")
  end

  # Tells the members among `keys` (participant keys just added) that `by`
  # gave them this chore. Nobody is told about assigning a chore to oneself,
  # and someone not yet in the household is not told.
  def notify_assignees(keys, by:)
    user_ids = keys.filter_map { |key| key.delete_prefix("user:").to_i if key.start_with?("user:") }
    User.where(id: user_ids).where.not(id: by.id).find_each do |user|
      Notifications::Notifier.call(Notifications::Events::TaskAssigned.new(self, assignee: user, assigned_by: by))
    end
  end

  # Times the household logged this chore, per author first name, most first.
  def log_counts_by_member
    chore_logs.joins(:user).group("users.first_name").order(Arel.sql("COUNT(*) DESC"), "users.first_name").count
  end

  private

  # A custom chore is listed under « Personnalisées »; its category, when
  # none is given, is "other".
  def normalise_custom_name
    self.custom_name = custom_name.to_s.squish.presence
    self.category = "other" if custom_chore? && category.blank?
  end

  # A catalogue chore saved without any load takes the task's defaults (older
  # chores were created before the catalogue had them).
  def take_task_loads
    return if mental_load || execution_load || task.nil?

    self.mental_load = task.default_mental_load
    self.execution_load = task.default_execution_load
  end

  # A monthly, yearly or one-off chore needs a due date to know which week it
  # falls in: today in the household's zone unless one is given.
  def default_anchor
    self.anchor_on ||= household&.today if anchored?
  end

  def custom_name_present
    return if catalogue_chore? || custom_name.present?

    errors.add(:custom_name, :blank)
  end

  def at_least_one_load
    errors.add(:loads, :at_least_one) unless mental_load || execution_load
  end

  def at_least_one_assignee
    errors.add(:assignees, :blank) if assignee_keys.empty?
  end

  def assignees_belong_to_household
    return unless household

    # Only new assignees are checked: a member who left keeps their rows
    # until their chores are handed over (lot 7).
    allowed = household.split_participants.map(&:key)
    added = chore_assignees.select { |a| a.new_record? && !a.marked_for_destruction? }.map(&:participant_key)
    unknown = Array(@invalid_assignee_keys) + (added - allowed)
    errors.add(:assignees, :not_in_household) if unknown.any?
  end
end
