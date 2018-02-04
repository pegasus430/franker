class ApplicationController < ActionController::Base
  before_filter :current_user, except: "register"
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  def current_user
    params[:uuid] ? User.find_by_uuid(params[:uuid]) : nil
  end
end