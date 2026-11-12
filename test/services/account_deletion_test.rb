require "test_helper"

# F5, backlog 3.6: deleting an account leaves the household, disposes of the
# logs (AccountDeletion#dispose_of_logs!) and anonymises the account.
class AccountDeletionTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    travel_to paris(2026, 11, 11, 10)
    @household, (@ann, @ben) = build_household("Ann", "Ben")
    @chore = @household.chores.create!(custom_name: "Courses", category: "other", mental_load: true, time_required: 10,
                                       assignee_user_ids: [ @ann.id ])
    @ann_logs = log!(@household, @ann, at: paris(2026, 11, 10, 9), chore: @chore, count: 2)
    @ben_log = log!(@household, @ben, at: paris(2026, 11, 10, 9), chore: @chore).first
    @week = @household.household_weeks.create!(
      week_start: Date.new(2026, 11, 2), time_zone: "Europe/Paris", status: "final", outcome: "balanced",
      fair_share: 50, mental_total: 4, computed_at: Time.current,
      members: [ { "user_id" => @ann.id, "first_name" => "Ann", "monogram" => "A", "mental_share" => 50 },
                 { "user_id" => @ben.id, "first_name" => "Ben", "monogram" => "B", "mental_share" => 50 } ]
    )
  end

  def delete_ann(**options)
    AccountDeletion.new(@ann, current_password: "password123", confirmed: "1", **options)
  end

  test "a wrong password or no confirmation deletes nothing" do
    d = AccountDeletion.new(@ann, current_password: "nope", confirmed: "1")
    assert_not d.save
    assert d.errors.of_kind?(:current_password, :invalid)

    d = AccountDeletion.new(@ann, current_password: "password123", confirmed: "0")
    assert_not d.save
    assert d.errors.of_kind?(:confirmed, :accepted)

    assert_equal "Ann", @ann.reload.first_name
    assert @ann.household
  end

  test "the account is anonymised and can no longer sign in" do
    old_email = @ann.email
    NotificationPreference.set(@ann, "weekly_report", false)
    ChorePreference.record!(@ann, @household, { @chore.id => "like" })

    assert delete_ann.save
    @ann.reload

    assert_equal "Ancien membre", @ann.first_name
    assert_not_equal old_email, @ann.email
    assert_match(/@supprime\.invalid\z/, @ann.email)
    assert_not @ann.valid_password?("password123")
    assert @ann.deleted?
    assert_not @ann.active_for_authentication?
    assert_nil @ann.household
    assert_not NotificationPreference.exists?(user_id: @ann.id)
    assert_not ChorePreference.exists?(user_id: @ann.id)
    assert_not Notification.exists?(user_id: @ann.id)
  end

  test "they leave the household first: chores handed over, the role passed on" do
    assert delete_ann.save

    assert_equal [ @ben.id ], @chore.reload.chore_assignees.map(&:user_id)
    assert membership(@household, @ben).manager?
    assert_equal 1, @household.household_members.count
  end

  test "dispose_of_logs! deletes the person's logs (decision 2026-11-12), never anyone else's" do
    assert delete_ann.save

    assert_not ChoreLog.where(id: @ann_logs.map(&:id)).exists?
    assert_equal 0, ChoreLog.where(user_id: @ann.id).count
    assert ChoreLog.exists?(@ben_log.id)
    assert_equal @household.id, @ben_log.reload.household_id
  end

  test "the other policy keeps the logs on the anonymised account, detached" do
    assert_equal :delete, AccountDeletion::LOGS_ON_DELETION

    assert delete_ann(logs_policy: :keep_anonymised).save

    kept = ChoreLog.where(id: @ann_logs.map(&:id)).to_a
    assert_equal 2, kept.size
    assert kept.all? { |log| log.user_id == @ann.id && log.household_id.nil? }
    assert_raises(ArgumentError) { AccountDeletion.new(@ann, logs_policy: :something) }
  end

  test "past snapshots keep their figures and read « Ancien membre »" do
    plan = WeekPlan.propose!(household: @household, by: @ben)
    Notifications::Notifier.call(Notifications::Events::TaskAssigned.new(@chore, assignee: @ben, assigned_by: @ann))

    assert delete_ann.save

    members = @week.reload.members
    assert_equal [ "Ancien membre", "Ben" ], members.map { |m| m["first_name"] }
    assert_equal [ "A", "B" ], members.map { |m| m["monogram"] }
    assert_equal [ 50, 50 ], members.map { |m| m["mental_share"] }
    assert_equal 4, @week.mental_total
    assert_predicate @week, :final?
    assert_not_includes plan.reload.participants.map { |p| p["first_name"] }, "Ann"
    facts = Notification.find_by!(user: @ben, kind: "task_assigned").facts
    assert_equal "Ancien membre", facts.dig("assigned_by", "first_name")
  end

  def invitation!(household, email:, first_name:, state:, invitee: nil, expires_at: 7.days.from_now)
    Invitation.new(household: household, email: email, first_name: first_name, state: state, invitee: invitee,
                   token_digest: SecureRandom.hex(32), expires_at: expires_at, last_sent_at: Time.current, created_at: Time.current)
              .tap { |invitation| invitation.save!(validate: false) }
  end

  test "every invitation that named them is anonymised, whatever its state" do
    other, (zoe, _) = build_household("Zoé")
    old_email = @ann.email
    accepted = invitation!(@household, email: "ann.old@test.com", first_name: "Ann", state: "accepted", invitee: @ann)
    pending = invitation!(other, email: old_email, first_name: "Annie", state: "pending")
    overdue = invitation!(other, email: "ann.other@test.com", first_name: "Ann", state: "pending", invitee: @ann, expires_at: 1.day.ago)
    declined = invitation!(other, email: old_email, first_name: "Ann", state: "declined")
    zoes = invitation!(other, email: "max@test.com", first_name: "Max", state: "pending")

    assert delete_ann.save
    @ann.reload

    [ accepted, pending, overdue, declined ].each(&:reload).each do |invitation|
      assert_equal @ann.email, invitation.email
      assert_equal "Ancien membre", invitation.first_name
    end
    assert_predicate pending, :cancelled?
    assert_predicate overdue, :expired?
    assert_predicate accepted, :accepted?
    assert_not Invitation.where("email = ? OR first_name IN (?)", old_email, %w[Ann Annie]).exists?
    assert_equal [ "max@test.com", "Max" ], [ zoes.reload.email, zoes.first_name ]
    assert_predicate zoes, :pending?
    assert_equal "Zoé", zoe.reload.first_name
  end

  test "the last member deleting their account deletes the household too" do
    household, users = build_household("Solo")
    solo = users.first

    assert AccountDeletion.new(solo, current_password: "password123", confirmed: true).save

    assert_not Household.exists?(household.id)
    assert solo.reload.deleted?
  end

  test "nobody else's data is touched" do
    other, (zoe, _) = build_household("Zoé")
    zoe_log = log!(other, zoe, at: paris(2026, 11, 10, 9)).first

    assert delete_ann.save

    assert_equal "Ben", @ben.reload.first_name
    assert_equal "Zoé", zoe.reload.first_name
    assert ChoreLog.exists?(zoe_log.id)
    assert_equal "Ben", @week.reload.members.last["first_name"]
  end
end
