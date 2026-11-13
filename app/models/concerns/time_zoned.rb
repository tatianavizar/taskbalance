# Shared validation for models that carry a `time_zone` column (IANA name).
module TimeZoned
  extend ActiveSupport::Concern

  included do
    validates :time_zone, presence: true, inclusion: { in: ->(_) { TZInfo::Timezone.all_identifiers }, allow_blank: true }
  end

  def zone
    ActiveSupport::TimeZone[time_zone]
  end

  def today
    zone.today
  end

  def current_week
    Week.current(time_zone)
  end

  def week_containing(time_or_date)
    Week.containing(time_or_date, time_zone)
  end
end
