# H1 (lot 8b): what the notifications will say, before the phone asks for the
# permission (decision 2026-11-08: at the end of the intro, I3 → H1 → A2, and
# again from Mon compte). Native shells only: a browser gets its messages by
# email and goes straight on.
#
# Public: the intro comes before sign-up. Without an account, the shell keeps
# the phone's token and the layout registers it once the person is signed in.
class PushPermissionsController < ApplicationController
  def show
    @next_path = user_signed_in? ? account_path : new_user_registration_path
    redirect_to @next_path unless hotwire_native_app?
  end
end
