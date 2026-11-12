module Notifications
  module Events
    # The gap between members was reset to zero (C9, backlog 2.4; D4 decides
    # who may do it). Every member is told; the text names no one.
    class GapReset < Event
      KIND = "gap_reset".freeze

      def initialize(household, week, token:)
        super(household)
        @week = week
        @token = token
      end

      def facts
        { "household_name" => household.name, "week_start" => @week.monday.iso8601, "week_number" => @week.number }
      end

      private

      # `token`: what makes this reset unique (the record that stores it).
      def key_parts = [ "household-#{household.id}", @week.monday.iso8601, @token ]
    end
  end
end
