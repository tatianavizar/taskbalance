require "test_helper"

class HouseholdsControllerTest < ActionDispatch::IntegrationTest
  test "destroy removes a household that still has chores and members" do
    sign_in users(:alice)
    household = households(:smith_home)
    assert household.chores.exists?
    assert household.household_members.exists?

    delete household_path(household)

    assert_redirected_to new_household_path
    assert_not Household.exists?(household.id)
    assert_equal 0, Chore.where(household_id: household.id).count
    assert_equal 0, HouseholdMember.where(household_id: household.id).count
  end

  test "index sends a member to their household" do
    sign_in users(:alice)
    get households_path
    assert_redirected_to household_path(households(:smith_home))
  end

  test "index sends someone without a household to the creation screen" do
    sign_in users(:dana)
    get households_path
    assert_redirected_to new_household_path
  end

  test "create makes the creator the manager, even when the email is unconfirmed" do
    dana = users(:dana)
    assert_not dana.confirmed?
    sign_in dana

    assert_difference [ "Household.count", "HouseholdMember.count" ], 1 do
      post households_path, params: { household: { name: "Chez Dana" } }
    end

    household = Household.find_by!(name: "Chez Dana")
    assert_redirected_to household_setup_path(household)
    assert_equal "partner", household.setup_step
    assert dana.reload.household_membership.manager?
    assert_equal dana.time_zone, household.time_zone
  end

  test "create with a blank or too long name re-renders and creates nothing" do
    sign_in users(:dana)

    assert_no_difference [ "Household.count", "HouseholdMember.count" ] do
      post households_path, params: { household: { name: "" } }
      assert_response :unprocessable_entity
      post households_path, params: { household: { name: "x" * 61 } }
      assert_response :unprocessable_entity
    end
  end

  test "a user who already has a household cannot create a second one" do
    sign_in users(:alice)

    assert_no_difference [ "Household.count", "HouseholdMember.count" ] do
      post households_path, params: { household: { name: "Second" } }
    end
    assert_redirected_to household_path(households(:smith_home))
    assert_predicate flash[:alert], :present?

    get new_household_path
    assert_redirected_to household_path(households(:smith_home))
  end

  test "someone cannot open another household" do
    sign_in users(:alice)
    get household_path(households(:jones_home))
    assert_response :not_found
  end

  test "someone cannot invite into a household that is not theirs" do
    sign_in users(:carol)
    assert_no_difference "Invitation.count" do
      post household_invitations_path(households(:smith_home)), params: { invitation: { email: "x@test.com" } }
    end
    assert_response :not_found
  end
end
