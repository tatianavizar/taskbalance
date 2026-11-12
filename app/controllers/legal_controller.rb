# CGU and privacy policy (decision 2026-11-12). Public pages, and drafts: they
# say « Brouillon, à valider juridiquement » until the project owner and a
# lawyer have gone through them. The publisher and host are placeholders.
class LegalController < ApplicationController
  before_action :set_back_path

  def terms; end

  def privacy; end

  private

  def set_back_path
    @back_path = user_signed_in? ? account_path : new_user_registration_path
  end
end
