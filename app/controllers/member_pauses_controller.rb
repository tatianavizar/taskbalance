# F6, F8, F10: declaring a pause, and the household's list of pauses.
#
# - F6: a pause for oneself, a start date, an optional end, a private reason.
# - F8: a pause for an absent member, after a regression and while it can
#   still be cancelled (D3). No reason: the person gives it, if they want.
# - F10: every pause with its dates, visible to all. A reason is visible only
#   to the member it belongs to (MemberPause#reason_for).
# Creating a pause already runs the engine and the notifications
# (MemberPause callbacks); nothing is triggered from here.
class MemberPausesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household
  before_action :set_pause, only: %i[edit update stop]

  def index
    @membership = @membership_of_viewer
    @pauses = @household.member_pauses.includes(household_member: :user).order(starts_on: :desc, id: :desc).to_a
    today = @household.today
    @current_and_next, @past = @pauses.partition { |pause| pause.ends_on.nil? || pause.ends_on >= today }
    @own_current = @current_and_next.find { |pause| pause.household_member_id == @membership.id && pause.starts_on <= today }
  end

  def new
    @target = target_membership
    return refuse_target unless @target

    @pause = MemberPause.new(household_member: @target, starts_on: prefilled_date(:du) || @household.today,
                             ends_on: prefilled_date(:au))
  end

  def create
    @target = target_membership
    return refuse_target unless @target

    @pause = MemberPause.new(household_member: @target, declared_by: current_user, starts_on: pause_params[:starts_on],
                             ends_on: pause_params[:ends_on].presence, reason: reason_from_params)
    if @pause.save
      redirect_to member_pauses_path, notice: created_notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  # « Modifier les dates »: only the end moves, never into the past (a start
  # or a past end would change closed weeks, which only a new declaration can).
  def edit
  end

  def update
    ends_on = pause_params[:ends_on].presence
    @pause.assign_attributes(ends_on: ends_on)
    if @pause.ends_on && @pause.ends_on < @household.today
      @pause.errors.add(:ends_on, :in_the_past)
      render :edit, status: :unprocessable_entity
    elsif @pause.save
      redirect_to member_pauses_path, notice: t("pauses.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # « Arrêter la pause »: ends today (or removes a pause that has not started).
  def stop
    @pause.cancel!(@household.today)
    redirect_to member_pauses_path, notice: t("pauses.flash.stopped")
  end

  private

  def set_household
    @household = current_user.household
    return redirect_to(dashboard_path) unless @household

    @membership_of_viewer = @household.household_members.find_by!(user_id: current_user.id)
  end

  # Only the member concerned changes or stops their pause.
  def set_pause
    @pause = @membership_of_viewer.member_pauses.find(params[:id])
  end

  # Oneself by default (F6). Someone else only for F8: a regression about them
  # that a pause can still cancel.
  def target_membership
    id = params[:pour].presence || params.dig(:member_pause, :household_member_id).presence
    return @membership_of_viewer if id.blank? || id.to_i == @membership_of_viewer.id

    other = @household.household_members.find_by(id: id)
    other if other && open_regression_for(other)
  end

  def refuse_target
    redirect_to member_pauses_path, alert: t("pauses.refused.not_declarable")
  end

  def open_regression_for(member)
    @household.absence_inquiries.regressed.where(household_member_id: member.id).any?(&:correction_window_open?)
  end

  def prefilled_date(key)
    Date.iso8601(params[key].to_s) if params[key].present?
  rescue Date::Error
    nil
  end

  def pause_params
    params.require(:member_pause).permit(:starts_on, :ends_on, :reason, :household_member_id)
  end

  # A reason belongs to the person concerned: a pause declared for someone
  # else never carries one.
  def reason_from_params
    pause_params[:reason].presence if @target.id == @membership_of_viewer.id
  end

  def created_notice
    cancelled = @household.level_changes.regression_cancelled.where(created_at: 1.minute.ago..).exists?
    cancelled ? t("pauses.flash.created_cancelling", level: @household.reload.level) : t("pauses.flash.created")
  end
end
