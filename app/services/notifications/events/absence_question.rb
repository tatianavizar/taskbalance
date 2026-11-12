module Notifications
  module Events
    # E11 / H5 / P9: a member logged nothing for two weeks in a row. The whole
    # household is asked, the member concerned included, whether they were
    # away. Sent Monday 08:00 after the closing; the answer is due Wednesday
    # 20:00 (the inquiry's deadline).
    class AbsenceQuestion < Event
      KIND = "absence_question".freeze

      def initialize(inquiry)
        super(inquiry.household)
        @inquiry = inquiry
      end

      def deliver_at = monday_morning_after(Week.new(@inquiry.last_week_start, household.zone))

      def facts
        week = Week.new(@inquiry.last_week_start, household.zone)
        {
          "household_name" => household.name,
          "subject" => person(@inquiry.household_member.user),
          "week_number" => week.number,
          "first_week_start" => @inquiry.first_week_start.iso8601,
          "last_week_end" => week.sunday.iso8601,
          "weeks" => 2,
          "deadline_on" => @inquiry.deadline_at.in_time_zone(household.zone).to_date.iso8601,
          "deadline_hour" => @inquiry.deadline_at.in_time_zone(household.zone).strftime("%H:%M")
        }
      end

      private

      def key_parts = [ "inquiry-#{@inquiry.id}" ]
    end
  end
end
