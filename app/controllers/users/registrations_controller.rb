class Users::RegistrationsController < Devise::RegistrationsController
  # Sign-up is an email-sending endpoint: limit it per IP, and per address so
  # nobody can flood someone's inbox with "you already have an account" mails.
  rate_limit to: 10, within: 1.hour, only: :create, name: "sign-up-ip",
             with: -> { rate_limited_redirect }
  rate_limit to: 3, within: 1.hour, only: :create, name: "sign-up-email",
             by: -> { params.dig(:user, :email).to_s.strip.downcase },
             with: -> { rate_limited_redirect }

  # Old invitation links pointed here: the invitation screen (B7) replaces it.
  def new
    if params[:invitation_token].present?
      session[:invitation_token] = params[:invitation_token]
      return redirect_to(invitation_path(params[:invitation_token]))
    end

    super
  end

  # The account screen (F4) replaces Devise's single edit form.
  def edit
    redirect_to account_path
  end

  # Account deletion (F5) is lot 7: it must anonymise and keep the logs, which
  # belong to their author. Until then Devise's DELETE /users is closed.
  def destroy
    raise ActionController::RoutingError, "Account deletion is not available yet"
  end

  def create
    build_resource(sign_up_params)
    # From the invitation screen the address is the invitation's, whatever was posted.
    resource.email = form_invitation.email if form_invitation
    skip_confirmation_if_invited(resource)

    # Anti-enumeration (A3, A5, A7): an address that already has an account
    # behaves like a success. The only message that leaves is sent to that
    # address ("you already have an account"), never shown to the visitor.
    existing = resource.email.present? && User.find_by(email: resource.email.strip.downcase)
    return respond_to_known_email(existing) if existing

    resource.save
    yield resource if block_given?
    if resource.persisted?
      redeem_invitation(resource)
      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      return render("invitations/join", locals: { invitation: form_invitation, user: resource }, status: :unprocessable_entity) if form_invitation

      respond_with resource
    end
  end

  protected

  # A new account lands on "confirm your email" (A10) until it is confirmed,
  # which never blocks anything (decision of 2026-11-08). An invited address
  # arrives confirmed and goes straight to the app.
  def after_sign_up_path_for(resource)
    invitation = pending_invitation_of(resource)
    return invitee_resume_path(invitation) if invitation

    resource.confirmed? ? dashboard_path : pending_user_confirmation_path
  end

  # The browser sends its zone; a name the server does not know is dropped so
  # that the account keeps the default instead of failing on a hidden field.
  def sign_up_params
    permitted = super
    permitted.delete(:time_zone) unless TZInfo::Timezone.all_identifiers.include?(permitted[:time_zone])
    permitted
  end

  private

  # A valid invitation token proves the address (the email went there), so the
  # account is confirmed from the start and no confirmation email is sent.
  def skip_confirmation_if_invited(user)
    return unless pending_invitation_for(user)

    user.skip_confirmation!
  end

  def invitation_token
    params[:invitation_token].presence || session[:invitation_token]
  end

  # The invitation behind the B7 form, when it is still usable.
  def form_invitation
    return @form_invitation if defined?(@form_invitation)

    token = params[:invitation_token].presence
    invitation = Invitation.find_by(token: token.to_s) if token
    @form_invitation = invitation&.usable? ? invitation : nil
  end

  def pending_invitation_for(user)
    return if invitation_token.blank? || user.email.blank?

    invitation = Invitation.find_by(token: invitation_token)
    invitation if invitation&.usable? && invitation.for?(user)
  end

  # Signing up through the link records the account as invitee: it does not
  # join the household. Joining waits for the last step of the setup, where
  # the person can still decline.
  def redeem_invitation(user)
    invitation = pending_invitation_for(user)
    return unless invitation

    invitation.claim_for!(user)
    session.delete(:invitation_token)
  end

  def respond_to_known_email(existing)
    # The other validations (password, first name...) still apply so that the
    # response does not differ from a sign-up with a new address.
    resource.valid?
    resource.errors.delete(:email, :taken)
    if resource.errors.any?
      clean_up_passwords resource
      set_minimum_password_length
      return respond_with(resource)
    end

    AccountMailer.already_registered(existing).deliver_later
    set_flash_message! :notice, :signed_up_but_unconfirmed
    redirect_to new_user_session_path
  end

  def rate_limited_redirect
    redirect_to new_user_registration_path, alert: t("devise.failure.rate_limited")
  end
end
