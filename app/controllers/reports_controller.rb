# The Bilan tab: the week's report (E1, E7, E10, E14) and the last four weeks
# (E2). The current week is read live (WeeklyStats), past weeks from their
# stored report (HouseholdWeek): see WeekReport.
class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household

  HISTORY_WEEKS = 4

  def show
    @week = requested_week(params[:semaine])
    @report = WeekReport.for(@household, @week)
    @viewer_line = @report.line_for(current_user)
    @current = @week.monday == @household.current_week.monday
    @alerts = HouseholdAlerts.new(@household, current_user) if @current
    @previous_week = (@week.previous if @week.monday > first_week.monday)
    @next_week = (@week.next unless @current)
    @first_report = @household.household_weeks.none? && @current && @report.silent?
  end

  def history
    @last_week = requested_week(params[:jusqu_a])
    weeks = Array.new(HISTORY_WEEKS) { |i| @last_week.monday - (7 * (HISTORY_WEEKS - 1 - i)) }
      .select { |monday| monday >= first_week.monday }
      .map { |monday| Week.new(monday, @household.zone) }
    @reports = weeks.map { |week| WeekReport.for(@household, week) }
    @current = @last_week.monday == @household.current_week.monday
    @previous_week = (@last_week.previous if @last_week.previous.monday >= first_week.monday)
    @next_week = (@last_week.next unless @current)
    @alerts = HouseholdAlerts.new(@household, current_user) if @current
  end

  private

  def set_household
    @household = current_user.household
    redirect_to dashboard_path unless @household
  end

  def first_week
    @first_week ||= @household.week_containing(@household.created_at)
  end

  # The Monday asked for, kept between the household's first week and the
  # current one. Anything unreadable gives the current week.
  def requested_week(param)
    current = @household.current_week
    date = Date.iso8601(param.to_s)
    week = @household.week_containing(date)
    return current if week.monday > current.monday

    week.monday < first_week.monday ? first_week : week
  rescue Date::Error
    current
  end
end
