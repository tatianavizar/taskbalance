require "test_helper"

# turbo_stream_from on a household stream: members only, at subscription time.
class HouseholdStreamsTest < ActionCable::Channel::TestCase
  include WeeklyEngineHelpers
  tests Turbo::StreamsChannel

  setup do
    @household, (@ann, @ben) = build_household("Ann", "Ben")
    @other, (@zoe, _) = build_household("Zoé")
    @stream = Household.home_stream(@household)
  end

  def subscribe_as(user, stream = @stream)
    stub_connection current_user: user
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name(stream)
  end

  test "a member subscribes to their household's stream" do
    subscribe_as @ann

    assert subscription.confirmed?
    assert_has_stream @stream
  end

  test "someone from another household is rejected, even with a validly signed name" do
    subscribe_as @zoe

    assert subscription.rejected?
  end

  test "a former member is rejected once they have left" do
    membership(@household, @ben).leave!
    subscribe_as @ben

    assert subscription.rejected?
  end

  test "leaving drops the leaver's open connections, nobody else's" do
    assert_broadcasts("action_cable/#{@ben.to_gid_param}", 1) do
      assert_no_broadcasts("action_cable/#{@ann.to_gid_param}") { membership(@household, @ben).leave! }
    end
    assert_equal({ "type" => "disconnect", "reconnect" => true }, broadcasts("action_cable/#{@ben.to_gid_param}").map { JSON.parse(_1) }.last)
  end

  test "a forged stream name is rejected; other streams are untouched" do
    stub_connection current_user: @zoe
    subscribe signed_stream_name: "forged"
    assert subscription.rejected?

    subscribe_as @zoe, "some:other:stream"
    assert subscription.confirmed?
  end

  test "the household of a stream name" do
    assert_equal @household.id, Household.household_id_from_stream(@stream)
    assert_equal 12, Household.household_id_from_stream("household:12")
    assert_nil Household.household_id_from_stream("households:12:home")
    assert_nil Household.household_id_from_stream("household:12abc")
  end
end
