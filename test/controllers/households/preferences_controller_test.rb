require "test_helper"

module Households
  class PreferencesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:alice)
      sign_in @user
      @household = households(:smith_home)
    end

    test "C3: three choices for every active chore, custom chores included" do
      get household_preferences_path(@household)

      assert_response :success
      assert_select "h1", "Vos préférences"
      assert_text "Fix the boiler"
      assert_select "input[type=radio][name=?]", "preferences[#{chores(:smith_custom).id}]", count: 3
      assert_select "label.segment-label", text: "Je n'aime pas", minimum: 1
      # Without an answer, it is « Neutre ».
      assert_select "input[type=radio][name=?][value=neutral][checked]", "preferences[#{chores(:smith_cooking).id}]"
    end

    test "update saves the current user's choices" do
      patch household_preferences_path(@household), params: {
        preferences: { chores(:smith_cooking).id => "like", chores(:smith_custom).id => "dislike" }
      }

      assert_redirected_to household_path(@household)
      assert_equal "like", ChorePreference.find_by(user: @user, chore: chores(:smith_cooking)).choice
      assert_equal "dislike", ChorePreference.find_by(user: @user, chore: chores(:smith_custom)).choice
    end

    test "nobody sees another member's preferences" do
      ChorePreference.create!(user: users(:bob), chore: chores(:smith_cooking), choice: "dislike")

      get household_preferences_path(@household)

      assert_select "input[type=radio][name=?][value=dislike][checked]", "preferences[#{chores(:smith_cooking).id}]", 0
    end

    test "a chore of another household is refused as a whole, nothing is written" do
      assert_no_difference "ChorePreference.count" do
        patch household_preferences_path(@household), params: {
          preferences: { chores(:smith_cooking).id => "like", chores(:jones_cooking).id => "like" }
        }
      end
      assert_response :unprocessable_entity
    end

    test "an unknown choice is refused" do
      assert_no_difference "ChorePreference.count" do
        patch household_preferences_path(@household), params: { preferences: { chores(:smith_cooking).id => "true" } }
      end
      assert_response :unprocessable_entity
    end

    test "another household's preferences are not reachable" do
      get household_preferences_path(households(:jones_home))
      assert_response :not_found
    end
  end
end
