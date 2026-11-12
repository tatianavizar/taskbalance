require "test_helper"

# B10, B11, B14 rendered for an invited participant. The request flow,
# through lot 3's access, is in test/integration/invitee_setup_test.rb.
class InviteeSplitScreensTest < ActionView::TestCase
  helper SplitHelper
  helper ComponentsHelper
  helper ApplicationHelper

  setup do
    @dana = users(:dana)
    @household = Household.create_for(@dana, name: "Chez Dana")
    @household.update!(setup_step: "done")
    @invitation = @household.invitations.create!(email: "karim@example.com")
    @karim = User.create!(email: "karim@example.com", first_name: "Karim", password: "secret123")
    @chore = @household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @dana.id ])
    participant = SplitParticipant.for_invitation(@invitation, color: "blue", user: @karim)
    view.define_singleton_method(:current_participant) { participant }
    @invitation.claim_for!(@karim)
    invitation = @invitation
    view.define_singleton_method(:current_invitation) { invitation }
    view.define_singleton_method(:hotwire_native_app?) { false }
    view.define_singleton_method(:user_signed_in?) { true }
  end

  def render_split
    @split = PlannedSplit.from_household(@household)
    render template: "households/splits/show"
  end

  test "B11: the split proposed by the creator, to change or accept by joining" do
    @plan = WeekPlan.propose!(household: @household, by: @dana, kind: :starting)
    render_split

    assert_includes rendered, "Bienvenue, Karim"
    assert_includes rendered, "Étape 2 sur 2"
    assert_includes rendered, "Proposée par Dana le"
    assert_includes rendered, "Rejoindre le foyer"
    assert_includes rendered, "Finalement, ne pas rejoindre ce foyer"
    assert_includes rendered, decline_invitation_path(@invitation.token)
    assert_includes rendered, "assignments[#{@chore.id}][]"
  end

  test "B14: the creator chose to wait, the invited person proposes" do
    @plan = WeekPlan.await_proposal!(household: @household)
    render_split

    assert_includes rendered, "Proposez la répartition"
    assert_includes CGI.unescapeHTML(rendered), "Dana a choisi de vous attendre"
    assert_includes rendered, "Proposer et rejoindre le foyer"
  end

  test "B10: the invited person's preferences, step 1 of 2, with a skip" do
    @chores = @household.chores.active.to_a
    @choices = {}
    render template: "households/preferences/show"

    assert_includes rendered, "Étape 1 sur 2"
    assert_includes CGI.unescapeHTML(rendered), "Les membres du foyer ne voient pas vos réponses"
    assert_includes CGI.unescapeHTML(rendered), "Passer : tout en « Neutre »"
  end
end
