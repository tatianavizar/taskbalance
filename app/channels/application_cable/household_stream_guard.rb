module ApplicationCable
  # Prepended to Turbo::StreamsChannel (config/initializers/turbo_streams.rb).
  #
  # A signed stream name never expires: someone who left a household still
  # holds the name of its live stream in an old page. So the signature is not
  # enough for a household stream (Household.home_stream): the person must be
  # a member of that household when subscribing. HouseholdDeparture also
  # drops the leaver's open connections, so an existing subscription ends and
  # cannot be renewed. `turbo_stream_from` works unchanged for members.
  module HouseholdStreamGuard
    def subscribed
      stream_name = verified_stream_name_from_params
      household_id = stream_name && Household.household_id_from_stream(stream_name)
      return reject if household_id && !member_of?(household_id)

      super
    end

    private

    def member_of?(household_id)
      user = connection.current_user
      user.present? && HouseholdMember.exists?(household_id: household_id, user_id: user.id)
    end
  end
end
