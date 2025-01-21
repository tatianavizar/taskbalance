class PagesController < ApplicationController
  def home
  end

  def dashboard
    current_user = @user
  end
end
