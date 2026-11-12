require "test_helper"

# F3, backlog 3.5: only the manager deletes the household, after typing its name.
class HouseholdDeletionTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    travel_to paris(2026, 11, 11, 10)
    @household, (@ann, @ben) = build_household("Ann", "Ben")
    @chore = @household.chores.create!(custom_name: "Courses", category: "other", mental_load: true, time_required: 10,
                                       assignee_user_ids: [ @ann.id, @ben.id ])
    @logs = [ log!(@household, @ann, at: paris(2026, 11, 10, 9), chore: @chore).first,
              log!(@household, @ben, at: paris(2026, 11, 10, 9)).first ]
  end

  def deletion(by: @ann, name: "Foyer test")
    HouseholdDeletion.new(@household, by: by, confirmation_name: name)
  end

  test "a member who does not manage the household cannot delete it" do
    d = deletion(by: @ben)
    assert_not d.allowed?
    assert_not d.save
    assert d.errors.of_kind?(:base, :not_manager)
    assert Household.exists?(@household.id)
  end

  test "a wrong name deletes nothing" do
    d = deletion(name: "Foyer")
    assert_not d.save
    assert d.errors.of_kind?(:confirmation_name, :mismatch)
    assert Household.exists?(@household.id)
    assert_not deletion(name: "foyer test").save, "case counts"
  end

  test "the manager deletes it: logs survive detached, members have no household, invitations are cancelled" do
    invitation = Invitation.invite(household: @household, email: "x@exemple.fr", first_name: "X", inviter: @ann)
    assert invitation.persisted?

    assert deletion(name: "  Foyer   test ").save

    assert_not Household.exists?(@household.id)
    assert_not Chore.exists?(@chore.id)
    assert_not Invitation.exists?(invitation.id)
    @logs.each do |log|
      log.reload
      assert_nil log.household_id
      assert log.detached?
    end
    assert_equal [ @ann.id, @ben.id ], @logs.map(&:user_id)
    assert_nil @ann.reload.household
    assert_nil @ben.reload.household
  end

  test "the other members are told; the message survives the household" do
    assert deletion.save

    notification = Notification.find_by!(user: @ben, kind: "household_deleted")
    assert_nil notification.household_id
    assert_equal "Ann a supprimé le foyer « Foyer test ».", notification.message.title
    assert_not Notification.exists?(user: @ann, kind: "household_deleted")
  end

  test "another household is untouched" do
    other, (zoe, _) = build_household("Zoé")
    assert deletion.save
    assert Household.exists?(other.id)
    assert zoe.reload.household
  end
end
