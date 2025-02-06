class PagesController < ApplicationController
  def home
  end

  def dashboard
    redirect_to user_session_path and return unless user_signed_in?
    current_user = @user
    current_user.tasks.empty? "this is empty" ; current_user.tasks
    @chores = current_user.chores
  end
end
