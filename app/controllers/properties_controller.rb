class PropertiesController < ApplicationController
  def set_clinic_holidays
    render :layout => "menu"
  end

  def create_clinic_holidays
    clinic_holidays = GlobalProperty.find_by_property('clinic.holidays')
    if clinic_holidays.blank?
      clinic_holidays = GlobalProperty.new()  if clinic_holidays.blank?
      clinic_holidays.property = 'clinic.holidays'
      clinic_holidays.description = 'day month year when clinic will be closed'
    end
    clinic_holidays.property_value = params[:holidays]
    clinic_holidays.save
    redirect_to '/clinic/properties' and return
  end

end
