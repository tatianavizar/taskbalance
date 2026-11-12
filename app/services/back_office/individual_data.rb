module BackOffice
  # A person's individual data, for a superadmin only (decision of
  # 2026-11-13: support may need it). Plain admins never reach it
  # (BackOfficeAuthorization), and every opening writes an AdminAction row
  # first: who looked, at whose data, in which household, which sections.
  #
  #   data = BackOffice::IndividualData.open(admin, user)
  #   data.logs  data.preferences  data.shares  data.gap_entries
  class IndividualData
    SECTIONS = %w[logs preferences shares gap_entries].freeze
    LOG_LIMIT = 200
    WEEK_LIMIT = 26

    class Refused < StandardError; end

    attr_reader :user, :household

    def self.open(admin, user)
      raise Refused, "superadmin only" unless admin&.superadmin? && !admin.deactivated?

      data = new(user)
      AdminAction.record!(admin: admin, action: "user.individual_data_viewed", record: user,
                          household_id: data.household&.id, sections: SECTIONS)
      data
    end

    def initialize(user)
      @user = user
      @household = user.household
    end

    # Their own logs, wherever they were made (logs follow the person).
    def logs
      @logs ||= user.chore_logs.order(completed_at: :desc, id: :desc).limit(LOG_LIMIT).to_a
    end

    def logs_count
      @logs_count ||= user.chore_logs.count
    end

    def preferences
      @preferences ||= user.chore_preferences.includes(chore: :task).order(:chore_id).to_a
    end

    # Their line in the weekly snapshots of their current household.
    def shares
      return [] unless household

      @shares ||= household.household_weeks.order(week_start: :desc).limit(WEEK_LIMIT).filter_map do |week|
        snapshot = week.member_snapshot(user)
        snapshot && { week: week, snapshot: snapshot }
      end
    end

    def gap_entries
      @gap_entries ||= SplitGapEntry.where(user: user).order(week_start: :desc, id: :desc).to_a
    end
  end
end
