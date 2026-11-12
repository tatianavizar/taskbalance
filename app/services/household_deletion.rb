# F3: the manager deletes the household (docs/backend-backlog.md 3.5). Also the
# form object of the F3 screen (`confirmation_name`, errors).
#
#   deletion = HouseholdDeletion.new(household, by: user, confirmation_name: "Chez nous")
#   deletion.save   # false with errors; true once the household is gone
#
# Rules:
#   - only the manager may delete (`allowed?`), after typing the household's
#     name (spaces around and doubled inside are ignored; case counts);
#   - the other members are told (Notifications::Events::HouseholdDeleted),
#     before the row goes;
#   - live invitations are cancelled, then go with the household;
#   - logs survive, detached (Household has_many :chore_logs, dependent:
#     :nullify, and the foreign keys nullify too). Members end up with no
#     household (F11).
class HouseholdDeletion
  include ActiveModel::Model

  attr_reader :household, :by
  attr_accessor :confirmation_name

  def initialize(household, by:, confirmation_name: nil)
    @household = household
    @by = by
    @confirmation_name = confirmation_name
  end

  def allowed?
    household.household_members.manager.exists?(user_id: by.id)
  end

  def name_matches?
    confirmation_name.to_s.squish == household.name.to_s.squish
  end

  def save
    errors.clear
    errors.add(:base, :not_manager) unless allowed?
    errors.add(:confirmation_name, :mismatch) if errors.empty? && !name_matches?
    return false if errors.any?

    Household.transaction do
      household.lock!
      Notifications::Notifier.call(Notifications::Events::HouseholdDeleted.new(household, deleted_by: by))
      household.invitations.live.find_each(&:cancel!)
      # Week plans and setting changes go with SQL deletes: their approvals too.
      Approval.where(approvable: household.week_plans).delete_all
      Approval.where(approvable: household.split_setting_changes).delete_all
      household.destroy!
    end
    by.association(:household_membership).reset
    true
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "HouseholdDeletion")
  end
end
