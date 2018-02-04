module Admin
  class SettingsController < AdminController

    def update_settings
      if params[:rate_this_app_enabled].present?
        rate_this_app_setting = (Setting.find_by key:'rate_this_app_enabled')
        rate_this_app_setting.value = params[:rate_this_app_enabled]
        rate_this_app_setting.save
      end
      redirect_to root_url
    end

  end
end