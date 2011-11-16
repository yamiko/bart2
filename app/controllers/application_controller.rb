class ApplicationController < ActionController::Base
  include AuthenticatedSystem
	  Mastercard
    PatientIdentifierType
    WeightHeight
    CohortTool
    Encounter
    EncounterType
    Location
    Task
    GlobalProperty
    Person

  require "fastercsv"

  helper :all
  helper_method :next_task
  filter_parameter_logging :password
  before_filter :login_required, :except => ['login', 'logout','demographics','create_remote', 'mastercard_printable']
  before_filter :location_required, :except => ['login', 'logout', 'location','demographics','create_remote', 'mastercard_printable']
  
  def rescue_action_in_public(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end
  
  def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    render :template => 'print/print_location', :layout => nil
  end

  def show_lab_results
    PatientService.get_global_property_value('show.lab.results') == "yes" rescue false
  end

  def use_filing_number
    PatientService.get_global_property_value('use.filing.number') == "yes" rescue false
  end    

 def generic_locations
  field_name = "name"

  Location.find_by_sql("SELECT *
          FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end

  def site_prefix
    site_prefix = PatientService.get_global_property_value("site_prefix") rescue false
    return site_prefix
  end

  def use_user_selected_activities
    PatientService.get_global_property_value('use.user.selected.activities') == "yes" rescue false
  end
  
  def tb_dot_sites_tag
    PatientService.get_global_property_value('tb_dot_sites_tag') rescue nil
  end

  def create_from_remote                                                        
    PatientService.get_global_property_value('create.from.remote') == "yes" rescue false
  end

  # Convert a list +Concept+s of +Regimen+s for the given +Patient+ <tt>age</tt>
  # into select options. See also +EncountersController#arv_regimen_answers+
  def regimen_options(regimen_concepts, age)
    options = regimen_concepts.map{ |r|
      [r.concept_id,

        (r.concept_names.typed("SHORT").first ||
        r.concept_names.typed("FULLY_SPECIFIED").first).name]
    }
	
    suffixed_options = options.collect{ |opt|
      opt_reg = Regimen.find(:all,
                             :select => 'regimen_index',
							 :order => 'regimen_index',
                             :conditions => ['concept_id = ?', opt[0]]
                            ).uniq.first
      if age >= 15
        suffix = "A"
      else
        suffix = "P"
      end

      #[opt[0], "#{opt_reg.regimen_index}#{suffix} - #{opt[1]}"]
		if opt_reg.regimen_index > -1
      		["#{opt_reg.regimen_index}#{suffix} - #{opt[1]}", opt[0], opt_reg.regimen_index.to_i]
		else
      		["#{opt[1]}", opt[0], opt_reg.regimen_index.to_i]
		end
    }.sort_by{|opt| opt[2]}

  end
  
  def checks_if_labs_results_are_avalable_to_be_shown(patient , session_date , task)
    lab_result = Encounter.find(:first,:order => "encounter_datetime DESC",
                                :conditions =>["DATE(encounter_datetime) <= ? 
                                AND patient_id = ? AND encounter_type = ?",
                                session_date.to_date ,patient.id,
                                EncounterType.find_by_name('LAB RESULTS').id])

    give_lab_results = Encounter.find(:first,:order => "encounter_datetime DESC",
                                :conditions =>["DATE(encounter_datetime) >= ? 
                                AND patient_id = ? AND encounter_type = ?",
                                lab_result.encounter_datetime.to_date , patient.id,
                                EncounterType.find_by_name('GIVE LAB RESULTS').id]) rescue nil

    if not lab_result.blank? and give_lab_results.blank?
      task.encounter_type = 'GIVE LAB RESULTS'
      task.url = "/encounters/new/give_lab_results?patient_id=#{patient.id}"
      return task
    end

    if not give_lab_results.blank?
      if not give_lab_results.observations.collect{|obs|obs.to_s.squish}.include?('Laboratory results given to patient: Yes')
        task.encounter_type = 'GIVE LAB RESULTS'
        task.url = "/encounters/new/give_lab_results?patient_id=#{patient.id}"
        return task
      end if not (give_lab_results.encounter_datetime.to_date == session_date.to_date)
    end
  end

private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end

end
