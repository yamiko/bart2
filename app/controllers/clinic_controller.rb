class ClinicController < ApplicationController
  def index
    @types = GlobalProperty.find_by_property("statistics.show_encounter_types").property_value rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ?', User.current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW())'])
    @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW())'])
    @ever = Encounter.statistics(@types)

    @facility = GlobalProperty.find_by_property("current_health_center_name").property_value rescue ""

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = User.find(session[:user_id]).name rescue ""

    render :template => 'clinic/index', :layout => false
  end

  def reports
    @reports = [
      ["Cohort","/cohort_tool/cohort_menu"],
      ["Supervision","/clinic/supervision"],
      ["Data Cleaning Tools", "/report/data_cleaning"],
      ["Stock report","/drug/date_select"]
    ]
    render :template => 'clinic/reports', :layout => 'clinic' 
  end

  def supervision
    @supervision_tools = [["Data that was Updated","summary_of_records_that_were_updated"],
      ["Drug Adherence Level","adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day", "visits_by_day"],
      ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

    @landing_dashboard = 'clinic_supervision'

    render :template => 'clinic/supervision', :layout => 'clinic' 
  end

  def properties
    @settings = [
      ["Set clinic days","/properties/clinic_days"],
      ["View clinic holidays","/properties/clinic_holidays"],
      ["Set clinic holidays","/properties/set_clinic_holidays"],
      ["Set site code", "/properties/site_code"],
      ["Set appointment limit", "/properties/set_appointment_limit"]
    ]
    render :template => 'clinic/properties', :layout => 'clinic' 
  end

  def management
    @reports = [
      ["New stock","delivery"],
      ["Edit stock","edit_stock"],
      ["Print Barcode","print_barcode"],
      ["Expiring drugs","date_select"],
      ["Removed from shelves","date_select"],
      ["Stock report","date_select"]
    ]
    render :template => 'clinic/management', :layout => 'clinic' 
  end

  def printing
    render :template => 'clinic/printing', :layout => 'clinic' 
  end

  def users
    render :template => 'clinic/users', :layout => 'clinic' 
  end

  def administration
    @reports = [['/clinic/users','User accounts/settings'],['/drug/management','Drug Management'], ['/location/management','Location Management']]
    @landing_dashboard = 'clinic_administration'
    render :template => 'clinic/administration', :layout => 'clinic' 
  end

  def overview_tab
    @types = GlobalProperty.find_by_property("statistics.show_encounter_types").property_value rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ?', User.current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW())'])
    @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW())'])
    @ever = Encounter.statistics(@types)

    render :layout => false
  end

  def reports_tab
    @reports = [
      ["Cohort","/cohort_tool/cohort_menu"],
      ["Supervision","/clinic/supervision_tab"],
      ["Data Cleaning Tools", "/report/data_cleaning_tab"],
      ["Stock report","/drug/date_select"]
    ]

    render :layout => false
  end

  def properties_tab
    @settings = [
      ["Set clinic days","/properties/clinic_days"],
      ["View clinic holidays","/properties/clinic_holidays"],
      ["Set clinic holidays","/properties/set_clinic_holidays"],
      ["Set site code", "/properties/site_code"],
      ["Set appointment limit", "/properties/set_appointment_limit"]
    ]
    render :layout => false
  end

  def administration_tab
    @reports = [['/clinic/users_tab','User accounts/settings'],
      ['/drug/management','Drug Management'], ['/location/management','Location Management']]
    @landing_dashboard = 'clinic_administration'
    render :layout => false
  end

  def supervision_tab
    @supervision_tools = [["Data that was Updated","summary_of_records_that_were_updated"],
      ["Drug Adherence Level","adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day", "visits_by_day"],
      ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

    @landing_dashboard = 'clinic_supervision'

    render :layout => false
  end

  def users_tab
    render :layout => false
  end

end
