class PropertiesController < ApplicationController
  def set_clinic_holidays
    render :layout => "menu"
  end

  def create_clinic_holidays
    if request.post? and not params[:holidays].blank?
      clinic_holidays = GlobalProperty.find_by_property('clinic.holidays')
      if clinic_holidays.blank?
        clinic_holidays = GlobalProperty.new()  
        clinic_holidays.property = 'clinic.holidays'
        clinic_holidays.description = 'day month year when clinic will be closed'
      end
      clinic_holidays.property_value = params[:holidays]
      clinic_holidays.save 
      flash[:notice] = 'Date(s) successfully created.'
      redirect_to '/properties/clinic_holidays' and return
    end
    redirect_to '/properties/set_clinic_holidays' and return
  end

  def clinic_holidays
    @holidays = GlobalProperty.find_by_property('clinic.holidays').property_value rescue []
    @holidays = @holidays.split(',').collect{|date|date.to_date}.sort unless @holidays.blank?
    render :layout => "menu"
  end

  def clinic_days
    if request.post? and not params[:age_group].blank?
      if params[:age_group] == 'Children'
        clinic_days = GlobalProperty.find_by_property('peads.clinic.days')
      else
        clinic_days = GlobalProperty.find_by_property('clinic.days')
      end

      if clinic_days.blank?
        clinic_days = GlobalProperty.new()  
        clinic_days.property = 'clinic.days'
        clinic_days.property = 'peads.clinic.days' if params[:age_group] == 'Children'
        clinic_days.description = 'Week days when the clinic is open'
      end
      weekdays = params[:weekdays].split(',').collect{ |wd|wd.capitalize }
      clinic_days.property_value = weekdays.join(',') 
      clinic_days.save 
      flash[:notice] = "Week day(s) successfully created.  (#{params[:age_group]})"
      redirect_to "/properties/show_clinic_days" and return
    end
    render :layout => "menu"
  end

  def show_clinic_days
    @clinic_days = week_days('clinic.days')
    @peads_clinic_days = week_days('peads.clinic.days')
    render :layout => "menu"
  end

  def week_days(property)
    wkdays = {}
    days = GlobalProperty.find_by_property(property).property_value rescue ''
    days.split(',').map do | day |
      wkdays[day] = 'X'
    end rescue nil
    return wkdays
  end

  def site_code
    if request.post?
      location = Location.find(Location.current_health_center.id)
      location.neighborhood_cell = params[:site_code]
      if location.save
        redirect_to "/clinic/properties" and return
      else
        flash[:error] = "Site code not created.  (#{params[:site_code]})"
      end
    end
  end
end