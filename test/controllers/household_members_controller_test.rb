require "test_helper"

class HouseholdMembersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = users(:alice)
    sign_in @user
    @household = households(:smith_home)
  end

  test "inviting an unknown email creates an invitation and sends it" do
    assert_difference "Invitation.count", 1 do
      assert_emails 1 do
        post household_household_members_path(@household),
             params: { household_member: { email: "newcomer@test.com" } }
      end
    end

    assert_redirected_to household_path(@household)
    invitation = Invitation.last
    assert_equal "newcomer@test.com", invitation.email
    assert_equal @household, invitation.household
    assert_predicate invitation.token, :present?
  end

  test "inviting the same email twice sends only one invitation" do
    post household_household_members_path(@household),
         params: { household_member: { email: "newcomer@test.com" } }

    assert_no_difference "Invitation.count" do
      assert_no_emails do
        post household_household_members_path(@household),
             params: { household_member: { email: "newcomer@test.com" } }
      end
    end
  end

  test "an invalid email re-renders the form instead of crashing" do
    assert_no_difference "Invitation.count" do
      assert_no_emails do
        post household_household_members_path(@household),
             params: { household_member: { email: "not-an-email" } }
      end
    end

    assert_response :unprocessable_entity
  end
end
