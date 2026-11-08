require "test_helper"

class HouseholdMemberTest < ActiveSupport::TestCase
  def user(first_name, email: "#{first_name.downcase}-#{SecureRandom.hex(3)}@test.com")
    User.create!(email: email, first_name: first_name, password: "password123")
  end

  def join(household, first_name, **attrs)
    HouseholdMember.create!(household: household, user: user(first_name), **attrs)
  end

  setup { @household = Household.create!(name: "Test") }

  test "role is member by default and the fixtures have a manager" do
    assert HouseholdMember.new.member?
    assert household_members(:alice_in_smith).manager?
  end

  test "an account can be in one household only" do
    duplicate = HouseholdMember.new(user: users(:alice), household: households(:jones_home))
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:user_id, :taken)
  end

  test "the database also refuses a second membership" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      HouseholdMember.new(user: users(:alice), household: households(:jones_home), color: "blue", monogram: "A").save!(validate: false)
    end
  end

  test "colours are handed out in palette order, and are unique in the household" do
    colors = %w[Ann Ben Cleo].map { |n| join(@household, n).color }
    assert_equal %w[mint blue stone], colors
  end

  test "a colour cannot be taken twice but can be changed to a free one" do
    first = join(@household, "Ann")
    second = join(@household, "Ben")
    second.color = first.color
    assert_not second.valid?
    second.color = "sage"
    assert second.valid?
    assert_equal %w[blue stone sky sand].sort, (second.available_colors - [ "sage" ]).sort | %w[blue]
  end

  test "colours outside the palette are refused" do
    member = join(@household, "Ann")
    member.color = "fuchsia"
    assert_not member.valid?
  end

  test "a colour freed by a departure is reused by the next arrival" do
    a = join(@household, "Ann")
    join(@household, "Ben")
    a.destroy!
    assert_equal "mint", join(@household, "Cleo").color
  end

  test "a household holds at most six people" do
    6.times { |i| join(@household, "P#{i}") }
    seventh = HouseholdMember.new(household: @household, user: user("Zed"))
    assert_not seventh.valid?
    assert seventh.errors.of_kind?(:base, :household_full)
  end

  test "the monogram is the initial when it is unique" do
    assert_equal "A", join(@household, "ann").monogram
    assert_equal "B", join(@household, "Ben").monogram
  end

  test "two letters appear only when two initials coincide, initial plus last letter" do
    kim = join(@household, "Kim")
    assert_equal "K", kim.monogram
    kate = join(@household, "Kate")

    assert_equal "Km", kim.reload.monogram
    assert_equal "Ke", kate.reload.monogram
    assert_equal "A", join(@household, "Ann").reload.monogram
  end

  test "a third person with the same initial still gets a distinct monogram" do
    kim = join(@household, "Kim")
    kate = join(@household, "Kate")
    karim = join(@household, "Karim")
    monograms = [ kim, kate, karim ].map { |m| m.reload.monogram }

    assert_equal 3, monograms.uniq.size
    assert monograms.all? { |m| m.length == 2 }
  end

  test "a hand-written monogram is kept when someone arrives" do
    kim = join(@household, "Kim")
    kim.customize_monogram!("KI")
    join(@household, "Kate")

    assert_equal "KI", kim.reload.monogram
    assert kim.monogram_customized?
  end

  test "a monogram has two letters at most" do
    kim = join(@household, "Kim")
    kim.monogram = "KIM"
    assert_not kim.valid?
    kim.monogram = ""
    assert_not kim.valid?
  end

  test "resetting a custom monogram gives the automatic one back" do
    kim = join(@household, "Kim")
    kim.customize_monogram!("Z")
    kim.reset_monogram!
    assert_equal "K", kim.monogram
    assert_not kim.monogram_customized?
  end

  test "leaving as manager hands the role to the oldest remaining member" do
    manager = join(@household, "Ann", role: :manager)
    second = join(@household, "Ben")
    third = join(@household, "Cleo")
    second.update_column(:created_at, 2.days.ago)
    third.update_column(:created_at, 1.day.ago)

    successor = manager.leave!

    assert_equal second, successor
    assert second.reload.manager?
    assert_not third.reload.manager?
    assert_not HouseholdMember.exists?(manager.id)
  end

  test "leaving as a simple member changes nobody's role" do
    manager = join(@household, "Ann", role: :manager)
    other = join(@household, "Ben")

    assert_nil other.leave!
    assert manager.reload.manager?
  end

  test "the last person leaving leaves an empty household without error" do
    manager = join(@household, "Ann", role: :manager)
    assert_nil manager.leave!
    assert_equal 0, @household.household_members.count
  end

  test "leaving never touches the person's logs" do
    alice = household_members(:alice_in_smith)
    chore = chores(:smith_cooking)
    log = ChoreLog.create!(chore: chore, user: alice.user, mental_load: true, execution_load: true, time_spent: 10, completed_at: Time.current)

    alice.leave!

    assert ChoreLog.exists?(log.id)
    assert_equal alice.user_id, log.reload.user_id
    assert household_members(:bob_in_smith).reload.manager?
  end
end
