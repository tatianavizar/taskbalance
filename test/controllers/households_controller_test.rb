require "test_helper"

class HouseholdsControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end

  test "destroy removes a household that still has chores and members" do
    sign_in users(:alice)
    household = households(:smith_home)
    assert household.chores.exists?
    assert household.household_members.exists?

    delete household_path(household)

    assert_redirected_to households_path
    assert_not Household.exists?(household.id)
    assert_equal 0, Chore.where(household_id: household.id).count
    assert_equal 0, HouseholdMember.where(household_id: household.id).count
  end
end
