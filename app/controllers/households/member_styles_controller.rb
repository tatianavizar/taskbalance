module Households
  # P2: a person's colour and letters in the household. A member edits their
  # own (from the household screen); a person invited to a household that
  # already has two members picks them before joining, kept on the invitation
  # until they accept. The colour is unique in the household: the ones taken
  # are shown, named and disabled. Leaving the letters empty gives the
  # automatic monogram back.
  class MemberStylesController < ApplicationController
    include SplitAccess

    before_action :authenticate_user!
    before_action :set_household
    before_action :set_subject

    def show; end

    def update
      color = params[:color].to_s
      letters = params[:monogram].to_s.strip

      @error = nil
      if @subject[:taken].key?(color) || HouseholdMember::COLORS.exclude?(color)
        @error = t("member_style.errors.color_taken")
      elsif letters.length > HouseholdMember::MONOGRAM_MAX_LENGTH
        @error = t("member_style.errors.monogram_length", max: HouseholdMember::MONOGRAM_MAX_LENGTH)
        @letters_error = true
      end
      return render_again(color, letters) if @error

      save(color, letters)
      if @invitation
        redirect_to household_preferences_path(@household)
      else
        redirect_to household_path(@household), notice: t("member_style.flash.saved")
      end
    end

    private

    def set_household
      @household = split_household!(params[:household_id])
    end

    # Either the member's own membership or, before joining, the invitation.
    def set_subject
      @membership = current_user.household_membership
      @invitation = (current_invitation unless @membership)
      raise ActiveRecord::RecordNotFound unless @membership || @invitation
      return redirect_to(waiting_invitation_path(@invitation.token)) if @invitation && !@household.setup_ready_for_invitee?

      @subject = build_subject
    end

    def build_subject
      if @membership
        others = @household.household_members.includes(:user).where.not(id: @membership.id)
        { color: @membership.color, monogram: @membership.monogram, custom: @membership.monogram_customized?,
          taken: others.to_h { |m| [ m.color, m.user.first_name ] }, name: current_user.first_name }
      else
        taken = @household.household_members.includes(:user).to_h { |m| [ m.color, m.user.first_name ] }
        @household.pending_invitations.where.not(id: @invitation.id).where.not(color: nil).each do |other|
          taken[other.color] = other.display_name
        end
        free = HouseholdMember::COLORS - taken.keys
        { color: @invitation.color || free.first, monogram: @invitation.monogram || automatic_monogram,
          custom: @invitation.monogram.present?, taken: taken, name: current_user.first_name }
      end
    end

    # The first-name initial, and initial + last letter when it is already
    # someone's initial (D16).
    def automatic_monogram
      name = current_user.first_name.to_s.strip
      initial = name.first.to_s.upcase
      shared = @household.household_members.includes(:user).any? { |m| m.initial == initial }
      shared && name.length > 1 ? initial + name.last.downcase : initial
    end

    def save(color, letters)
      if @membership
        @membership.update!(color: color)
        if letters.blank?
          @membership.reset_monogram! if @membership.monogram_customized?
        elsif letters != @membership.monogram
          @membership.customize_monogram!(letters)
        end
      else
        @invitation.update!(color: color, monogram: (letters.presence unless letters == automatic_monogram))
      end
    end

    def render_again(color, letters)
      @subject = @subject.merge(color: color, monogram: letters, custom: letters.present?)
      render :show, status: :unprocessable_entity
    end
  end
end
