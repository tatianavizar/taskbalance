require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  setup do
    @household = households(:smith_home)
  end

  test "a new invitation is valid and gets a token before validation" do
    invitation = @household.invitations.new(email: "new@test.com")

    assert invitation.valid?
    assert_predicate invitation.token, :present?
  end

  test "save generates a token and persists" do
    invitation = @household.invitations.create!(email: "new@test.com")

    assert_predicate invitation.reload.token, :present?
  end

  test "tokens are unique per invitation" do
    a = @household.invitations.create!(email: "a@test.com")
    b = @household.invitations.create!(email: "b@test.com")

    assert_not_equal a.token, b.token
  end

  test "the token is not regenerated on update" do
    invitation = @household.invitations.create!(email: "new@test.com")
    token = invitation.token

    invitation.update!(email: "renamed@test.com")

    assert_equal token, invitation.reload.token
  end

  test "an invalid email is rejected" do
    assert_not @household.invitations.new(email: "not-an-email").valid?
  end
end
