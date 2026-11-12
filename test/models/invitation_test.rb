require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
  end

  def invite(email, inviter: @alice)
    Invitation.invite(household: @household, email: email, inviter: inviter)
  end

  # ---- Creation -------------------------------------------------------------

  test "a new invitation is valid, gets a token, a 14-day expiry and a send date" do
    invitation = @household.invitations.new(email: "new@test.com")

    assert invitation.valid?
    assert_predicate invitation.token, :present?
    assert_in_delta 14.days.from_now, invitation.expires_at, 5
    assert_predicate invitation, :pending?
    assert_equal 0, invitation.resend_count
  end

  test "the token is not regenerated on update" do
    invitation = @household.invitations.create!(email: "new@test.com")
    token = invitation.token

    invitation.update!(email: "renamed@test.com")

    assert_equal token, invitation.reload.token
  end

  test "emails are stored trimmed and lowercased" do
    assert_equal "new@test.com", @household.invitations.create!(email: "  New@Test.com ").email
  end

  test "the database allows only one pending invitation per email and household" do
    @household.invitations.create!(email: "new@test.com")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Invitation.new(household: @household, email: "new@test.com", token: "other", expires_at: 1.day.from_now, last_sent_at: Time.current).save!(validate: false)
    end
  end

  # ---- Errors (B4) ------------------------------------------------------------

  test "an address without a complete domain is refused" do
    invitation = invite("karim.benali@gmail")

    assert_not invitation.persisted?
    assert_includes invitation.errors.messages_for(:email).first, "Adresse incomplète"
    assert_predicate invite("karim@gmail.").errors[:email], :any?
  end

  test "an invalid address is refused" do
    assert invite("not-an-email").errors.of_kind?(:email, :invalid)
    assert invite("").errors.of_kind?(:email, :blank)
  end

  test "the inviter cannot invite their own address, whatever its case" do
    assert invite("ALICE@test.com").errors.of_kind?(:email, :own_email)
  end

  test "a member of the household cannot be invited, and the message names them" do
    invitation = invite(users(:bob).email)

    assert invitation.errors.of_kind?(:email, :already_member)
    assert_includes invitation.errors.messages_for(:email).first, "Bob"
  end

  test "an address with a pending invitation cannot be invited again" do
    first = invite("new@test.com")
    second = invite("new@test.com")

    assert first.persisted?
    assert second.errors.of_kind?(:email, :already_invited)
  end

  test "the household holds six people at most, pending invitations included" do
    4.times { |i| @household.invitations.create!(email: "p#{i}@test.com") }
    assert_equal 2, @household.household_members.count

    invitation = invite("seventh@test.com")

    assert invitation.errors.of_kind?(:base, :household_full)
  end

  test "an address that has an account elsewhere is invited like any other" do
    assert invite(users(:carol).email).persisted?
    assert invite(users(:dana).email).persisted?
  end

  test "inviting sends one email" do
    assert_enqueued_emails 1 do
      invite("new@test.com")
    end
    assert_no_enqueued_emails do
      invite("not-an-email")
    end
  end

  # ---- State machine ------------------------------------------------------------

  test "a pending invitation past its date reads as expired, and expire_overdue! writes it" do
    invitation = @household.invitations.create!(email: "new@test.com")

    travel 15.days do
      assert_not invitation.usable?
      assert_equal "expired", invitation.current_state
      Invitation.expire_overdue!
      assert_predicate invitation.reload, :expired?
    end
  end

  test "an expired invitation frees the address for a new one" do
    @household.invitations.create!(email: "new@test.com")

    travel 15.days do
      assert_predicate invite("new@test.com"), :persisted?
    end
  end

  test "cancel closes a pending invitation once" do
    invitation = @household.invitations.create!(email: "new@test.com")

    assert invitation.cancel!
    assert_predicate invitation.reload, :cancelled?
    assert_not_nil invitation.cancelled_at
    assert_not invitation.cancel!
  end

  test "the addressee can decline, others cannot" do
    invitation = @household.invitations.create!(email: "dana@test.com")

    assert_not invitation.decline!(users(:carol))
    assert invitation.decline!(users(:dana))
    assert_predicate invitation.reload, :declined?
    assert_not_nil invitation.declined_at
    assert_not invitation.decline!(users(:dana))
  end

  test "declining leaves the household and its members untouched" do
    invitation = @household.invitations.create!(email: "dana@test.com")

    assert_no_difference [ "HouseholdMember.count", "Household.count" ] do
      invitation.decline!(users(:dana))
    end
    assert_nil users(:dana).household
  end

  test "a declined address can be invited again" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.decline!(users(:dana))

    travel 16.minutes do
      assert_predicate invite("dana@test.com"), :persisted?
    end
  end

  # ---- Claiming and joining ------------------------------------------------------

  test "claiming records the invitee and grants pre-join setup access to them alone" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    dana = users(:dana)

    assert_not invitation.grants_setup_access_to?(dana)
    assert invitation.claim_for!(dana)

    assert_equal dana, invitation.reload.invitee
    assert invitation.grants_setup_access_to?(dana)
    assert_not invitation.grants_setup_access_to?(users(:carol))
    assert_not invitation.grants_setup_access_to?(nil)
    assert_nil dana.household, "claiming does not join"
  end

  test "an invitation for another address cannot be claimed" do
    invitation = @household.invitations.create!(email: "dana@test.com")

    assert_not invitation.claim_for!(users(:carol))
    assert_nil invitation.reload.invitee
  end

  test "someone already in a household cannot claim: they leave theirs first (D13)" do
    invitation = @household.invitations.create!(email: users(:carol).email)

    assert_not invitation.claim_for!(users(:carol))
    assert_nil invitation.reload.invitee
  end

  test "setup access ends when the invitation is cancelled, declined or expired" do
    dana = users(:dana)
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.claim_for!(dana)
    assert invitation.grants_setup_access_to?(dana)

    travel(15.days) { assert_not invitation.grants_setup_access_to?(dana) }

    invitation.cancel!
    assert_not invitation.grants_setup_access_to?(dana)

    invitation.update_columns(state: "pending", cancelled_at: nil)
    assert invitation.grants_setup_access_to?(dana)
    invitation.decline!(dana)
    assert_not invitation.grants_setup_access_to?(dana)
  end

  test "access stops once the invitee is in a household" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.claim_for!(users(:dana))
    Household.create_for(users(:dana), name: "Chez Dana")

    assert_not invitation.reload.grants_setup_access_to?(User.find(users(:dana).id))
  end

  test "accept! joins only after the claim, then closes the invitation" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    dana = users(:dana)

    assert_not invitation.accept!(dana), "joining without having gone through the setup is refused"
    assert_nil dana.reload.household

    invitation.claim_for!(dana)
    membership = invitation.accept!(dana)

    assert_equal @household, dana.reload.household
    assert_predicate membership, :member?
    assert_predicate invitation.reload, :accepted?
    assert_not_nil invitation.accepted_at
  end

  test "accept! refuses when the household is full" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.claim_for!(users(:dana))
    4.times do |i|
      user = User.create!(email: "m#{i}@test.com", first_name: "M#{i}", password: "password123", confirmed_at: Time.current)
      @household.household_members.create!(user: user)
    end

    assert_not invitation.accept!(users(:dana))
    assert_predicate invitation.reload, :pending?
    assert_nil users(:dana).reload.household
  end

  test "accept! refuses someone who is in a household" do
    invitation = @household.invitations.create!(email: users(:carol).email)
    invitation.update_columns(invitee_id: users(:carol).id)

    assert_not invitation.accept!(users(:carol))
    assert_equal households(:jones_home), users(:carol).household
  end

  test "live_for_invitee finds the invitation being worked through" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    assert_nil Invitation.live_for_invitee(users(:dana))

    invitation.claim_for!(users(:dana))
    assert_equal invitation, Invitation.live_for_invitee(users(:dana))
  end

  test "deleting the invitee's account keeps the invitation" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.claim_for!(users(:dana))

    users(:dana).destroy!

    assert_nil invitation.reload.invitee_id
  end

  # ---- Resends (D12) --------------------------------------------------------------

  test "resend keeps the token, resets the expiry and sends a new email" do
    invitation = @household.invitations.create!(email: "new@test.com")
    token = invitation.token

    travel 16.minutes do
      assert_enqueued_emails 1 do
        assert_equal [ :ok ], invitation.resend!
      end
      invitation.reload
      assert_equal token, invitation.token
      assert_equal 1, invitation.resend_count
      assert_in_delta 14.days.from_now, invitation.expires_at, 5
    end
  end

  test "resends are spaced by 15 minutes and the verdict gives the remaining wait" do
    invitation = @household.invitations.create!(email: "new@test.com")

    travel 5.minutes do
      verdict, seconds = invitation.resend!
      assert_equal :wait, verdict
      assert_in_delta 10.minutes, seconds, 2
    end
    assert_equal 0, invitation.reload.resend_count
    travel 15.minutes + 1 do
      assert_equal [ :ok ], invitation.resend!
    end
  end

  test "three resends at most, then the limit" do
    invitation = @household.invitations.create!(email: "new@test.com")
    3.times do |i|
      travel_to(Time.current + ((i + 1) * 20).minutes) { assert_equal [ :ok ], invitation.resend! }
    end

    travel_to 2.hours.from_now do
      assert_equal [ :limit ], invitation.resend!
      assert_equal [ :limit ], invitation.resend_allowance
    end
    assert_equal 3, invitation.reload.resend_count
  end

  test "cancelling and inviting again does not reset the resend counter (counted per email and household)" do
    invitation = @household.invitations.create!(email: "new@test.com")
    travel_to(20.minutes.from_now) { invitation.resend! }
    travel_to(40.minutes.from_now) { invitation.resend! }
    invitation.cancel!

    travel_to 1.hour.from_now do
      assert_equal 2, Invitation.resends_used(household_id: @household.id, email: "new@test.com")
      again = invite("new@test.com")
      assert again.persisted?
      assert_equal 1, again.resend_count, "inviting again counts as a send after the first"
      assert_equal 3, Invitation.resends_used(household_id: @household.id, email: "NEW@test.com")
    end

    travel_to 2.hours.from_now do
      Invitation.find_by!(email: "new@test.com", state: "pending").cancel!
      limited = invite("new@test.com")
      assert limited.errors.of_kind?(:email, :resend_limit)
    end
  end

  test "inviting again right after a cancel waits for the 15-minute gap" do
    invitation = @household.invitations.create!(email: "new@test.com")
    invitation.cancel!

    again = invite("new@test.com")
    assert again.errors.of_kind?(:email, :resend_wait)

    travel 16.minutes do
      assert_predicate invite("new@test.com"), :persisted?
    end
  end

  test "the counter is per household: another household starts from zero" do
    @household.invitations.create!(email: "new@test.com", resend_count: 3)

    other = Invitation.invite(household: households(:jones_home), email: "new@test.com", inviter: users(:carol))

    assert_predicate other, :persisted?
    assert_equal 0, other.resend_count
  end

  test "a closed invitation cannot be resent" do
    invitation = @household.invitations.create!(email: "new@test.com")
    invitation.cancel!

    assert_equal [ :closed ], invitation.resend!
  end

  # ---- Races (security review) ------------------------------------------------------

  test "accept! re-reads the row: a cancel that committed meanwhile wins" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.claim_for!(users(:dana))
    stale = Invitation.find(invitation.id)
    invitation.cancel!

    assert_not stale.accept!(User.find(users(:dana).id))
    assert_predicate invitation.reload, :cancelled?
    assert_nil users(:dana).reload.household
  end

  test "accept! turns a unique-index collision into an error, not an exception" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.claim_for!(users(:dana))
    HouseholdMember.class_eval { alias_method :__save, :save; define_method(:save) { |*| raise ActiveRecord::RecordNotUnique, "dup" } }
    begin
      assert_not invitation.accept!(User.find(users(:dana).id))
    ensure
      HouseholdMember.class_eval { alias_method :save, :__save; remove_method :__save }
    end
    assert_predicate invitation.errors[:base], :any?
    assert_predicate invitation.reload, :pending?
  end

  test "resend! checks the limit under the row lock, on fresh data" do
    invitation = @household.invitations.create!(email: "new@test.com")
    stale = Invitation.find(invitation.id)

    travel 16.minutes do
      assert_equal [ :ok ], invitation.resend!
      verdict, = stale.resend! # a second request that loaded the row before the first committed
      assert_equal :wait, verdict
    end
    assert_equal 1, invitation.reload.resend_count
  end

  test "cancel! on a closed invitation is false" do
    invitation = @household.invitations.create!(email: "dana@test.com")
    invitation.decline!(users(:dana))

    assert_not invitation.cancel!
    assert_predicate invitation.reload, :declined?
  end
end
