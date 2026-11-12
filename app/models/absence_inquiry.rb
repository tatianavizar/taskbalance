# Opened by the final report that gives a member their second consecutive
# empty week (backlog "Non-logging", 2.1, 2.2b). Every member, the absent one
# included, is asked whether that member was away (E11, P5) and answers "yes"
# or "no" until `deadline_at` (Wednesday 20:00 after the closing, household
# zone).
# - One "yes" from anyone declares the pause over the two weeks at once: the
#   inquiry becomes `paused`, no regression.
# - "No" answers are recorded. Without any "yes" by the deadline, the
#   household regresses one level and is blocked (`regressed`, WeeklyEngine).
# - The member concerned can correct an answer made about them before the
#   deadline. If that leaves no "yes", the pause it declared is withdrawn and
#   the inquiry is pending again.
#
# == Query API for the screens (E11, P5)
#   inquiry.concerned_member / concerned_first_name
#   inquiry.respondents            every current member, arrival order
#   inquiry.answer_for(member_or_user)   AbsenceAnswer or nil
#   inquiry.answered_members / unanswered_members
#   inquiry.answers_summary        { yes: 1, no: 1, unanswered: 1 }
#   inquiry.accepting_answers?(now)
#   inquiry.deadline_at
#   inquiry.current_outcome(now)   :awaiting_answers, :away_declared,
#                                  :regression_due (deadline passed, engine not
#                                  run yet), :regressed, :regression_cancelled
#   inquiry.can_answer?(user, now) / can_correct?(answer, user, now)
#   inquiry.correctable_answers(user, now)
#   AbsenceInquiry.open_for(household, now) / awaiting_answer_from(user, now)
#
# == Writes (both raise AnswerRefused with a reason, see REFUSALS)
#   inquiry.answer!(by: user, value: "yes" | "no", at: Time.current)
#   inquiry.correct!(answer, by: user, value: "yes" | "no", at: Time.current)
class AbsenceInquiry < ApplicationRecord
  DEADLINE_WDAY_OFFSET = HouseholdRules::ABSENCE_DEADLINE_DAY_OFFSET # Wednesday, counted from the Monday of the closing
  DEADLINE_HOUR = HouseholdRules::ABSENCE_DEADLINE_HOUR
  REFUSALS = %i[invalid_answer closed not_a_member not_concerned not_correctable].freeze

  class AnswerRefused < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("absence answer refused: #{reason}")
    end
  end

  belongs_to :household
  belongs_to :household_member
  has_many :absence_answers, dependent: :delete_all

  # cancelled: the regression applied at the deadline was undone by a pause
  # declared afterwards, within the window (D3).
  enum :status, { pending: "pending", paused: "paused", regressed: "regressed", cancelled: "cancelled" }, validate: true

  validates :first_week_start, :last_week_start, :deadline_at, presence: true

  scope :due, ->(now) { pending.where(deadline_at: ..now) }
  scope :open_at, ->(now) { where(status: %w[pending paused]).where("absence_inquiries.deadline_at > ?", now) }

  # Wednesday 20:00 of the week after `last_week`, in its zone.
  def self.deadline_for(last_week)
    day = last_week.next.monday + DEADLINE_WDAY_OFFSET
    last_week.time_zone.local(day.year, day.month, day.day, DEADLINE_HOUR)
  end

  # Inquiries of the household still taking answers.
  def self.open_for(household, now = Time.current)
    household.absence_inquiries.open_at(now).order(:deadline_at, :id)
  end

  # Open inquiries in the user's household that the user has not answered.
  def self.awaiting_answer_from(user, now = Time.current)
    membership = HouseholdMember.find_by(user_id: user&.id)
    return none if membership.nil?

    open_for(membership.household, now)
      .where.not(id: AbsenceAnswer.where(household_member_id: membership.id).select(:absence_inquiry_id))
  end

  # ---- queries ---------------------------------------------------------------

  def concerned_member = household_member
  def concerned_first_name = household_member.user.first_name

  def respondents
    household.household_members.includes(:user).order(:created_at, :id).to_a
  end

  def answer_for(member_or_user)
    member_id = member_id_for(member_or_user)
    absence_answers.find { |answer| answer.household_member_id == member_id }
  end

  def answered_members
    ids = absence_answers.map(&:household_member_id)
    respondents.select { |member| ids.include?(member.id) }
  end

  def unanswered_members
    respondents - answered_members
  end

  def answers_summary
    answers = absence_answers.to_a
    { yes: answers.count(&:yes?), no: answers.count(&:no?), unanswered: unanswered_members.size }
  end

  def accepting_answers?(now = Time.current)
    (pending? || paused?) && now < deadline_at
  end

  def current_outcome(now = Time.current)
    case status
    when "paused" then :away_declared
    when "regressed" then :regressed
    when "cancelled" then :regression_cancelled
    else now < deadline_at ? :awaiting_answers : :regression_due
    end
  end

  def can_answer?(user, now = Time.current)
    accepting_answers?(now) && member_id_for(user).present?
  end

  def can_correct?(answer, user, now = Time.current)
    accepting_answers?(now) && user&.id == household_member.user_id &&
      answer.absence_inquiry_id == id && !answer.by_concerned_member?
  end

  def correctable_answers(user, now = Time.current)
    absence_answers.select { |answer| can_correct?(answer, user, now) }
  end

  # ---- writes ----------------------------------------------------------------

  # The answer of `by` (any current member, the absent one included). Answering
  # again replaces the previous answer; the same answer twice changes nothing.
  def answer!(by:, value:, at: Time.current)
    value = checked_value(value)
    household.with_lock do
      reload
      raise AnswerRefused, :closed unless accepting_answers?(at)

      member = household.household_members.find_by(user_id: by&.id) or raise AnswerRefused, :not_a_member
      answer = absence_answers.find_or_initialize_by(household_member: member)
      next answer if answer.persisted? && answer.answer == value

      changed = answer.persisted?
      answer.update!(answer: value, answered_at: at, original_answer: nil, corrected_at: nil)
      record_event("absence_answer.given", answer, at, respondent_member_id: member.id,
                   respondent_user_id: member.user_id, answer: value, changed: changed)
      apply_answers!(actor: by, at: at)
      answer.reload
    end
  end

  # The member concerned corrects an answer someone else made about them.
  def correct!(answer, by:, value:, at: Time.current)
    value = checked_value(value)
    household.with_lock do
      reload
      answer.reload
      raise AnswerRefused, :closed unless accepting_answers?(at)
      raise AnswerRefused, :not_concerned unless by&.id == household_member.user_id
      raise AnswerRefused, :not_correctable if answer.absence_inquiry_id != id || answer.by_concerned_member?
      next answer if answer.answer == value

      original = answer.original_answer || answer.answer
      answer.update!(answer: value, original_answer: original, corrected_at: at)
      record_event("absence_answer.corrected", answer, at, respondent_member_id: answer.household_member_id,
                   original_answer: original, answer: value, corrected_by_user_id: by.id)
      apply_answers!(actor: by, at: at)
      answer.reload
    end
  end

  # ---- engine ----------------------------------------------------------------

  # The inquiry's weeks stay open to a retroactive pause (and the regression
  # to cancellation) until the next final report after the deadline: the
  # Monday 03:00 closing the week after `last_week_start` (D3).
  def correction_window_end
    HouseholdWeek.final_at(Week.new(last_week_start, household.zone).next)
  end

  def correction_window_open?(now = Time.current)
    now < correction_window_end
  end

  def covers_week?(week)
    week.monday.between?(first_week_start, last_week_start)
  end

  def weeks
    zone = household.zone
    [ Week.new(first_week_start, zone), Week.new(last_week_start, zone) ]
  end

  def covered_by_pause?
    weeks.any? { |week| household_member.member_pauses.overlapping(week).exists? }
  end

  # "Yes, they were away": declares the pause over the two empty weeks.
  def answer_yes!(by:)
    MemberPause.declare!(
      member: household_member, declared_by: by,
      starts_on: first_week_start, ends_on: last_week_start + 6
    )
  end

  private

  def checked_value(value)
    value = value.to_s
    raise AnswerRefused, :invalid_answer unless AbsenceAnswer::VALUES.include?(value)

    value
  end

  def member_id_for(member_or_user)
    case member_or_user
    when HouseholdMember then member_or_user.id
    when User then respondents.find { |member| member.user_id == member_or_user.id }&.id
    end
  end

  # Brings the pause in line with the answers: a "yes" means a pause declared
  # by an answer; no "yes" left means that pause goes (WeeklyEngine).
  def apply_answers!(actor:, at:)
    answers = absence_answers.reload.order(:answered_at, :id).to_a
    yes = answers.select(&:yes?)
    holder = answers.find(&:member_pause_id)

    if yes.any?
      if holder.nil?
        if pending?
          pause = answer_yes!(by: actor)
          yes.first.update!(member_pause: pause)
          reload
        end
      elsif holder.no?
        holder_pause = holder.member_pause
        holder.update!(member_pause: nil)
        yes.first.update!(member_pause: holder_pause)
      end
    elsif holder
      pause = holder.member_pause
      holder.update!(member_pause: nil)
      WeeklyEngine.new(household).pause_withdrawn(pause, self, now: at) if pause
      reload
    end
  end

  def record_event(name, answer, at, **payload)
    EngineEvent.record!(household: household, name: name, subject: answer, at: at,
                        inquiry_id: id, answer_id: answer.id, **payload)
  end
end
