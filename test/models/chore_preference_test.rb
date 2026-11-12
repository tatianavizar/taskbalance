require "test_helper"

class ChorePreferenceTest < ActiveSupport::TestCase
  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
  end

  test "three choices only" do
    assert ChorePreference.new(user: @alice, chore: chores(:smith_cooking), choice: "neutral").valid?
    assert_not ChorePreference.new(user: @alice, chore: chores(:smith_cooking), choice: "love").valid?
  end

  test "one preference per person and chore" do
    ChorePreference.create!(user: @alice, chore: chores(:smith_cooking), choice: "like")
    assert_not ChorePreference.new(user: @alice, chore: chores(:smith_cooking), choice: "dislike").valid?
  end

  test "record! writes the person's choices, custom chores included" do
    assert ChorePreference.record!(@alice, @household, { chores(:smith_cooking).id => "like", chores(:smith_custom).id => "dislike" })
    assert_equal({ chores(:smith_cooking).id => "like", chores(:smith_custom).id => "dislike" },
                 ChorePreference.choices_for(@alice, [ chores(:smith_cooking), chores(:smith_custom) ]))

    ChorePreference.record!(@alice, @household, { chores(:smith_cooking).id => "neutral" })
    assert_equal "neutral", ChorePreference.find_by(user: @alice, chore: chores(:smith_cooking)).choice
  end

  test "record! refuses a chore of another household and writes nothing" do
    assert_no_difference "ChorePreference.count" do
      assert_not ChorePreference.record!(@alice, @household, { chores(:smith_cooking).id => "like", chores(:jones_cooking).id => "like" })
    end
  end

  test "record! refuses a retired chore and an unknown choice" do
    chores(:smith_laundry).update_column(:active, false)
    assert_not ChorePreference.record!(@alice, @household, { chores(:smith_laundry).id => "like" })
    assert_not ChorePreference.record!(@alice, @household, { chores(:smith_cooking).id => "adore" })
  end

  test "each person only reads their own choices" do
    ChorePreference.create!(user: users(:bob), chore: chores(:smith_cooking), choice: "dislike")
    assert_empty ChorePreference.choices_for(@alice, [ chores(:smith_cooking) ])
  end
end
