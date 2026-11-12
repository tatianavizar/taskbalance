require "test_helper"

# What the team can write from /admin: each action works, respects its
# limits and leaves a row in the audit log.
class BackOfficeActionsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @admin = sign_in_team!
    @household = households(:smith_home)
    @alice = users(:alice)
  end

  def invite(email = "karim@example.com", inviter: @alice)
    Invitation.invite(household: @household, email: email, inviter: inviter, first_name: "Karim")
  end

  def last_entry
    AdminAction.order(:id).last
  end

  # ---- Resend ---------------------------------------------------------------

  test "the team resends an invitation it did not send: same email, counted, logged" do
    invitation = invite
    invitation.update_columns(last_sent_at: 20.minutes.ago)

    assert_enqueued_emails 1 do
      post resend_admin_invitation_path(invitation)
    end
    assert_redirected_to admin_invitation_path(invitation)
    assert_equal "Invitation renvoyée.", flash[:notice]
    assert_equal 1, invitation.reload.resend_count

    assert_equal "invitation.resent", last_entry.action
    assert_equal @admin, last_entry.admin_user
    assert_equal @admin.email, last_entry.admin_email
    assert_equal [ "Invitation", invitation.id ], [ last_entry.record_type, last_entry.record_id ]
    assert_equal @household.id, last_entry.detail["household_id"]
  end

  test "resending keeps the app's limits: 15 minutes apart" do
    invitation = invite

    assert_no_enqueued_emails do
      assert_no_difference "AdminAction.count" do
        post resend_admin_invitation_path(invitation)
      end
    end
    assert_redirected_to admin_invitation_path(invitation)
    assert_match(/moins de 15 minutes/, flash[:alert])
    assert_equal 0, invitation.reload.resend_count
  end

  test "resending keeps the app's limits: 3 sends in all" do
    invitation = invite
    2.times do
      invitation.update_columns(last_sent_at: 20.minutes.ago)
      post resend_admin_invitation_path(invitation)
      assert_equal "Invitation renvoyée.", flash[:notice]
    end
    assert_equal 2, invitation.reload.resend_count

    invitation.update_columns(last_sent_at: 20.minutes.ago)
    assert_no_enqueued_emails do
      assert_difference "AdminAction.count", 0 do
        post resend_admin_invitation_path(invitation)
      end
    end
    assert_match(/3 envois/, flash[:alert])
    assert_equal 2, invitation.reload.resend_count
  end

  test "a closed invitation cannot be resent" do
    invitation = invite
    invitation.cancel!
    assert_no_enqueued_emails { post resend_admin_invitation_path(invitation) }
    assert_match(/en cours/, flash[:alert])
    assert_not AdminAction.exists?(action: "invitation.resent")
  end

  test "an admin counts as someone who may resend; an unrelated app user does not" do
    invitation = invite
    assert invitation.resendable_by?(@admin)
    assert invitation.resendable_by?(@alice)
    assert_not invitation.resendable_by?(users(:bob))
    assert_not invitation.resendable_by?(nil)
  end

  # ---- Cancel ---------------------------------------------------------------

  test "the team cancels a pending invitation, and it is logged" do
    invitation = invite
    post cancel_admin_invitation_path(invitation)
    assert_redirected_to admin_invitation_path(invitation)
    assert_equal "Invitation annulée.", flash[:notice]
    assert_predicate invitation.reload, :cancelled?
    assert_equal "invitation.cancelled", last_entry.action
  end

  test "an invitation already closed cannot be cancelled again" do
    invitation = invite
    invitation.cancel!
    assert_no_difference "AdminAction.count" do
      post cancel_admin_invitation_path(invitation)
    end
    assert_match(/en cours/, flash[:alert])
  end

  # ---- Unblock --------------------------------------------------------------

  def block!(household)
    household.update!(state: "blocked", blocked_at: 3.days.ago, level: 2, balanced_weeks_count: 4)
  end

  test "the team unblocks a household: state back, level and counter untouched, an engine event says who" do
    block!(@household)

    assert_difference -> { @household.engine_events.where(name: "household.admin_unblocked").count }, 1 do
      post unblock_admin_household_path(@household)
    end
    assert_redirected_to admin_household_path(@household)
    assert_match(/Foyer débloqué/, flash[:notice])

    @household.reload
    assert_equal "active", @household.state
    assert_nil @household.blocked_at
    assert_equal 2, @household.level
    assert_equal 4, @household.balanced_weeks_count

    event = @household.engine_events.find_by!(name: "household.admin_unblocked")
    assert_equal @admin.id, event.payload["admin_user_id"]
    assert_equal "household.unblocked", last_entry.action
    assert_equal @household.id, last_entry.record_id
  end

  test "unblocking a household of one goes back to solo" do
    solo = Household.create_for(users(:dana), name: "Dana seule")
    block!(solo)
    post unblock_admin_household_path(solo)
    assert_equal "solo", solo.reload.state
  end

  test "a household that is not blocked is left alone" do
    assert_no_difference [ "AdminAction.count", "EngineEvent.count" ] do
      post unblock_admin_household_path(@household)
    end
    assert_match(/n'est pas bloqué/, flash[:alert])
  end

  test "the unblock event is not delivered as a notification" do
    block!(@household)
    post unblock_admin_household_path(@household)
    assert_no_difference "Notification.count" do
      Notifications::Dispatcher.deliver_pending(@household)
    end
  end

  # ---- Confirm email --------------------------------------------------------

  test "the team confirms an email, and it is logged" do
    dana = users(:dana)
    assert_nil dana.confirmed_at
    post confirm_email_admin_user_path(dana)
    assert_redirected_to admin_user_path(dana)
    assert_equal "Email confirmé.", flash[:notice]
    assert_not_nil dana.reload.confirmed_at
    assert_equal "user.email_confirmed", last_entry.action
    assert_equal [ "User", dana.id ], [ last_entry.record_type, last_entry.record_id ]
  end

  test "an email already confirmed is not logged again" do
    assert_no_difference "AdminAction.count" do
      post confirm_email_admin_user_path(@alice)
    end
    assert_match(/déjà confirmé/, flash[:alert])
  end

  # ---- Delete an account ----------------------------------------------------

  test "deleting an account needs the typed email: without it nothing happens" do
    bob = users(:bob)
    assert_no_difference "AdminAction.count" do
      post delete_account_admin_user_path(bob), params: { typed_email: "someone@else.com" }
    end
    assert_redirected_to admin_user_path(bob)
    assert_match(/ne correspond pas/, flash[:alert])
    assert_not bob.reload.deleted?

    post delete_account_admin_user_path(bob)
    assert_not bob.reload.deleted?
  end

  test "the team deletes an account: same rules as the person, logs deleted, logged" do
    bob = users(:bob)
    ChoreLog.create!(user: bob, chore: chores(:smith_custom), household: @household,
                     mental_load: true, execution_load: false, time_spent: 10, completed_at: Time.current)
    alice_log = ChoreLog.create!(user: @alice, chore: chores(:smith_custom), household: @household,
                                 mental_load: true, execution_load: true, time_spent: 15, completed_at: Time.current)

    assert_difference -> { ChoreLog.where(user_id: bob.id).count }, -1 do
      post delete_account_admin_user_path(bob), params: { typed_email: " Bob@Test.com " }
    end
    assert_redirected_to admin_user_path(bob)
    assert_match(/Compte supprimé/, flash[:notice])

    bob.reload
    assert_predicate bob, :deleted?
    assert_equal AccountDeletion::ANONYMOUS_FIRST_NAME, bob.first_name
    assert_nil bob.household_membership
    assert ChoreLog.exists?(alice_log.id), "other people's logs stay"

    assert_equal "user.account_deleted", last_entry.action
    assert_equal bob.id, last_entry.record_id
    assert_equal @household.id, last_entry.detail["household_id"]
    assert_equal true, last_entry.detail["logs_deleted"]
    assert_no_match(/bob/i, last_entry.detail.to_json, "no email or name in the log detail")
  end

  test "an account already deleted cannot be deleted again" do
    bob = users(:bob)
    post delete_account_admin_user_path(bob), params: { typed_email: bob.email }
    assert_difference "AdminAction.count", 0 do
      post delete_account_admin_user_path(bob), params: { typed_email: bob.reload.email }
    end
    assert_match(/déjà supprimé/, flash[:alert])
  end

  test "the person's own deletion still needs their password" do
    bob = users(:bob)
    deletion = AccountDeletion.new(bob, confirmed: "1")
    assert_not deletion.save
    assert_not bob.reload.deleted?
    assert_not AccountDeletion.new(bob).respond_to?(:typed_email)
  end

  # ---- Every action needs the session ---------------------------------------

  test "without a back-office session no action runs" do
    delete destroy_admin_user_session_path
    invitation = invite
    block!(@household)

    post resend_admin_invitation_path(invitation)
    post cancel_admin_invitation_path(invitation)
    post unblock_admin_household_path(@household)
    post confirm_email_admin_user_path(users(:dana))
    post delete_account_admin_user_path(users(:bob)), params: { typed_email: "bob@test.com" }

    assert_equal 0, invitation.reload.resend_count
    assert_predicate invitation, :pending?
    assert_predicate @household.reload, :blocked?
    assert_nil users(:dana).reload.confirmed_at
    assert_not users(:bob).reload.deleted?
    assert_equal 0, AdminAction.where.not(action: "two_factor.enrolled").count
  end

  test "an app user cannot run any action" do
    delete destroy_admin_user_session_path
    sign_in @alice
    invitation = invite
    post cancel_admin_invitation_path(invitation)
    assert_redirected_to "/admin/login"
    assert_predicate invitation.reload, :pending?
  end

  # ---- Audit log ------------------------------------------------------------

  test "the journal lists the actions, read-only" do
    invitation = invite
    post cancel_admin_invitation_path(invitation)

    get "/admin/admin_actions"
    assert_response :success
    assert_text "Invitation annulée"
    assert_text @admin.email

    entry = last_entry
    get "/admin/admin_actions/#{entry.id}"
    assert_response :success

    assert_raises(ActiveRecord::ReadOnlyRecord) { entry.update!(action: "household.unblocked") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { entry.destroy }
    assert_not_includes Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(%r{admin_actions}).join, "edit"
  end

  test "a row of the journal outlives the admin account" do
    invitation = invite
    post cancel_admin_invitation_path(invitation)
    entry = last_entry
    @admin.destroy!
    assert_nil entry.reload.admin_user_id
    assert_equal "team@cinquante.test", entry.admin_email
  end
end
