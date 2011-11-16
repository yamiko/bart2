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
    get_global_property_value('show.lab.results') == "yes" rescue false
  end

  def use_filing_number
    get_global_property_value('use.filing.number') == "yes" rescue false
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
    site_prefix = get_global_property_value("site_prefix") rescue false
    return site_prefix
  end

  def use_user_selected_activities
    get_global_property_value('use.user.selected.activities') == "yes" rescue false
  end
  
  def tb_dot_sites_tag
    get_global_property_value('tb_dot_sites_tag') rescue nil
  end

  def create_from_remote                                                        
    get_global_property_value('create.from.remote') == "yes" rescue false
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

  def patient_national_id_label(patient)
	patient_bean = get_patient(patient.person)
    return unless patient_bean.national_id
    sex =  patient_bean.sex.match(/F/i) ? "(F)" : "(M)"
    address = patient.person.address.strip[0..24].humanize rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{patient_bean.national_id}")
    label.draw_multi_text("#{patient_bean.name.titleize}")
    label.draw_multi_text("#{patient_bean.national_id_with_dashes} #{patient_bean.birth_date}#{sex}")
    label.draw_multi_text("#{address}")
    label.print(1)
  end

  #moved to patient_service but left this because it's referenced in other methods
  def patient_hiv_status(patient)
    status = Concept.find(Observation.find(:first,
    :order => "obs_datetime DESC,date_created DESC",
    :conditions => ["value_coded IS NOT NULL AND person_id = ? AND concept_id = ?", patient.id,
    ConceptName.find_by_name("HIV STATUS").concept_id]).value_coded).fullname rescue "UNKNOWN"
    if status.upcase == 'UNKNOWN'
      return patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') ? 'Positive' : status
    end
    return status
  end
=begin
  def get_patients_identifier(patient, identifier_type, force = false)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name(identifier_type).id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name(identifier_type).next_identifier(:patient => patient).identifier
    id
  end
=end

 def patient_is_child?(patient)
   return get_patient_attribute_value(patient, "age") <= 14 unless get_patient_attribute_value(patient, "age").nil?
   return false
 end

 def get_patient_attribute_value(patient, attribute_name)
 	
   patient_bean = get_patient(patient.person)
   if patient_bean.sex.upcase == 'MALE'
   		sex = 'M'
   elsif patient_bean.sex.upcase == 'FEMALE'
   		sex = 'F'
   end
   
   case attribute_name.upcase
     when "AGE"
       return patient_bean.age
     when "RESIDENCE"
       return patient_bean.address
     when "CURRENT_HEIGHT"
      obs = patient.person.observations.recent(1).question("HEIGHT (CM)").all
      return obs.first.value_numeric rescue 0
     when "CURRENT_WEIGHT"
      obs = patient.person.observations.recent(1).question("WEIGHT (KG)").all
      return obs.first.value_numeric rescue 0
     when "INITIAL_WEIGHT"
      obs = patient.person.observations.old(1).question("WEIGHT (KG)").all
      return obs.last.value_numeric rescue 0
     when "INITIAL_HEIGHT"
      obs = patient.person.observations.old(1).question("HEIGHT (CM)").all
      return obs.last.value_numeric rescue 0
     when "INITIAL_BMI"
      obs = patient.person.observations.old(1).question("BMI").all
      return obs.last.value_numeric rescue nil
     when "MIN_WEIGHT"
      return WeightHeight.min_weight(sex, patient_bean.age_in_months).to_f
     when "MAX_WEIGHT"
      return WeightHeight.max_weight(sex, patient_bean.age_in_months).to_f
     when "MIN_HEIGHT"
      return WeightHeight.min_height(sex, patient_bean.age_in_months).to_f
     when "MAX_HEIGHT"
      return WeightHeight.max_height(sex, patient_bean.age_in_months).to_f
   end

 end

 def patient_tb_status(patient)
   Concept.find(Observation.find(:first,
    :order => "obs_datetime DESC,date_created DESC",
    :conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL",
                    patient.id,
    ConceptName.find_by_name("TB STATUS").concept_id]).value_coded).fullname rescue "UNKNOWN"
 end
 
  def get_global_property_value(global_property)
    GlobalProperty.find(:first,
                        :conditions => {:property => "#{global_property}"}
                       ).property_value
  end

 def reason_for_art_eligibility(patient)
    reasons = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue nil
 end

 def patient_appointment_dates(patient, start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Observation.find(:all,
      :conditions => ["DATE(obs.value_datetime) >= ? AND DATE(obs.value_datetime) <= ? AND " +
          "obs.concept_id = ? AND obs.voided = 0 AND obs.person_id = ?", start_date.to_date,
        end_date.to_date, appointment_date_concept_id, patient.id])

    appointments
  end

  def get_patient_identifier(patient, identifier_type)
    patient_identifier_type_id = PatientIdentifierType.find_by_name(identifier_type).patient_identifier_type_id
    patient_identifier = PatientIdentifier.find(:first, :select => "identifier",
                                                :conditions  =>["patient_id = ? and identifier_type = ?", patient.id, patient_identifier_type_id],
                                                :order => "date_created DESC" ).identifier rescue nil
    return patient_identifier
  end

  def prescribe_arv_this_visit(patient, date = Date.today)
    encounter_type = EncounterType.find_by_name('ART VISIT')
    yes_concept = ConceptName.find_by_name('YES').concept_id
    refer_concept = ConceptName.find_by_name('PRESCRIBE ARVS THIS VISIT').concept_id
    refer_patient = Encounter.find(:first,
      :joins => 'INNER JOIN obs USING (encounter_id)',
      :conditions => ["encounter_type = ? AND concept_id = ? AND person_id = ? AND value_coded = ? AND DATE(obs_datetime) = ?",
        encounter_type.id,refer_concept,patient.id,yes_concept,date.to_date],
      :order => 'encounter_datetime DESC,date_created DESC')
    return false if refer_patient.blank?
    return true
  end

  def drug_given_before(patient, date = Date.today)
    encounter_type = EncounterType.find_by_name('TREATMENT')
    Encounter.find(:first,
      :joins => 'INNER JOIN orders ON orders.encounter_id = encounter.encounter_id
               INNER JOIN drug_order ON orders.order_id = orders.order_id',
      :conditions => ["quantity IS NOT NULL AND encounter_type = ? AND
               encounter.patient_id = ? AND DATE(encounter_datetime) < ?",
        encounter_type.id,patient.id,date.to_date],
        :order => 'encounter_datetime DESC,date_created DESC').orders rescue []
  end

  def get_patient(person)
    patient = Mastercard.new()
    patient.person_id = person.id
    patient.patient_id = person.patient.id
    patient.arv_number = get_patient_identifier(person.patient, 'ARV Number')
    patient.address = person.addresses.first.city_village
    patient.national_id = get_patient_identifier(person.patient, 'National id')    
		patient.national_id_with_dashes = PatientService.get_national_id_with_dashes(person.patient)
    patient.name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
    patient.sex = PatientService.sex(person)
    patient.age = age(person)
    patient.age_in_months = PatientService.age_in_months(person)
    patient.dead = person.dead
    patient.birth_date = PatientService.birthdate_formatted(person)
    patient.birthdate_estimated = person.birthdate_estimated
    patient.home_district = person.addresses.first.address2
    patient.traditional_authority = person.addresses.first.county_district
    patient.current_residence = person.addresses.first.city_village
    patient.mothers_surname = person.names.first.family_name2
    patient.eid_number = get_patient_identifier(person.patient, 'EID Number')
    patient.pre_art_number = get_patient_identifier(person.patient, 'Pre ART Number (Old format)')
    patient.archived_filing_number = get_patient_identifier(person.patient, 'Archived filing number')
    patient.filing_number = get_patient_identifier(person.patient, 'Filing Number')
    patient.occupation = PatientService.get_attribute(person, 'Occupation')
    patient.guardian = art_guardian(patient_obj) rescue nil 
    patient
  end

  def name(person)
    "#{person.names.first.given_name} #{person.names.first.family_name}".titleize rescue nil
  end
  
  def age(person, today = Date.today)
    return nil if person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + ((today.month - person.birthdate.month) + ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=person.birthdate
    estimate=person.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  && 
      today.month < birth_date.month && person.date_created.year == today.year) ? 1 : 0
  end

private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end

end
