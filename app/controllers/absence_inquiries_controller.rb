# E11, P5: the absence question. Every member of the household, the absent one
# included, answers « Oui » or « Non » until Wednesday 20:00; the member
# concerned can correct an answer someone gave about them. The rules and the
# refusals live in AbsenceInquiry (#answer!, #correct!, AnswerRefused).
class AbsenceInquiriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household
  before_action :set_inquiry, only: %i[show answer correct]

  # The notification link: the open question, or the list when there are several.
  def index
    @inquiries = AbsenceInquiry.open_for(@household).includes(household_member: :user).to_a
    redirect_to absence_inquiry_path(@inquiries.first) if @inquiries.one?
  end

  def show
    @membership = @household.household_members.find_by!(user_id: current_user.id)
    @concerned = @inquiry.household_member_id == @membership.id
    @weeks = inquiry_weeks
    @answers = @inquiry.absence_answers.includes(:household_member).index_by(&:household_member_id)
    @correctable = @inquiry.correctable_answers(current_user).map(&:id)
    @pause_open = @inquiry.regressed? && @inquiry.correction_window_open?
  end

  def answer
    answer = @inquiry.answer!(by: current_user, value: params[:answer])
    redirect_to absence_inquiry_path(@inquiry), notice: t("absence.flash.answered.#{answer.answer}")
  rescue AbsenceInquiry::AnswerRefused => e
    redirect_to absence_inquiry_path(@inquiry), alert: t("absence.refusals.#{e.reason}")
  end

  def correct
    answer = @inquiry.absence_answers.find(params[:answer_id])
    corrected = @inquiry.correct!(answer, by: current_user, value: params[:answer])
    redirect_to absence_inquiry_path(@inquiry), notice: t("absence.flash.corrected.#{corrected.answer}")
  rescue AbsenceInquiry::AnswerRefused => e
    redirect_to absence_inquiry_path(@inquiry), alert: t("absence.refusals.#{e.reason}")
  end

  private

  def set_household
    @household = current_user.household
    redirect_to dashboard_path unless @household
  end

  def set_inquiry
    @inquiry = @household.absence_inquiries.includes(household_member: :user).find(params[:id])
  end

  # What the member concerned logged in each of the two empty weeks, from the
  # stored reports.
  def inquiry_weeks
    user_id = @inquiry.household_member.user_id
    @inquiry.weeks.map do |week|
      record = @household.household_weeks.find_by(week_start: week.monday)
      { week: week, count: record&.member_snapshot(user_id)&.dig("logs_count").to_i }
    end
  end
end
