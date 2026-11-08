require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  test "the name is required" do
    household = Household.new(name: "  ")
    assert_not household.valid?
    assert household.errors.of_kind?(:name, :blank)
  end

  test "the name is limited to 60 characters" do
    assert Household.new(name: "a" * 60).valid?
    household = Household.new(name: "a" * 61)
    assert_not household.valid?
    assert household.errors.of_kind?(:name, :too_long)
  end

  test "the time zone defaults to Europe/Paris and must be a real zone" do
    assert_equal "Europe/Paris", Household.new.time_zone
    assert_not Household.new(name: "X", time_zone: "Mars/Olympus").valid?
    assert Household.new(name: "X", time_zone: "America/Montreal").valid?
  end

  test "week helpers read the household time zone" do
    household = Household.new(name: "X", time_zone: "America/Montreal")
    assert_equal "America/Montreal", household.current_week.time_zone.name
  end

  test "create_for makes the creator the manager and uses their time zone" do
    user = User.create!(email: "founder@test.com", first_name: "Fanny", password: "password123", time_zone: "America/Montreal")

    household = Household.create_for(user, name: "Chez Fanny")

    assert household.persisted?
    assert_equal "America/Montreal", household.time_zone
    membership = user.reload.household_membership
    assert membership.manager?
    assert_equal household, user.household
    assert_equal "F", membership.monogram
    assert_equal "mint", membership.color
  end

  test "create_for refuses a user who already has a household" do
    assert_no_difference [ "Household.count", "HouseholdMember.count" ] do
      household = Household.create_for(users(:alice), name: "Second foyer")
      assert_not household.persisted?
      assert household.errors.of_kind?(:base, :user_already_in_household)
    end
  end

  test "create_for creates nothing when the household is invalid" do
    assert_no_difference [ "Household.count", "HouseholdMember.count" ] do
      assert_not Household.create_for(users(:dana), name: "").persisted?
    end
  end
end
