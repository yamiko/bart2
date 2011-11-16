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
	patient.national_id_with_dashes = get_national_id_with_dashes(person.patient)
    patient.name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
    patient.sex = sex(person)
    patient.age = age(person)
    patient.age_in_months = age_in_months(person)
    patient.dead = person.dead
    patient.birth_date = birthdate_formatted(person)
    patient.birthdate_estimated = person.birthdate_estimated
    patient.home_district = person.addresses.first.address2
    patient.traditional_authority = person.addresses.first.county_district
    patient.current_residence = person.addresses.first.city_village
    patient.mothers_surname = person.names.first.family_name2
    patient.eid_number = get_patient_identifier(person.patient, 'EID Number')
    patient.pre_art_number = get_patient_identifier(person.patient, 'Pre ART Number (Old format)')
    patient.archived_filing_number = get_patient_identifier(person.patient, 'Archived filing number')
    patient.filing_number = get_patient_identifier(person.patient, 'Filing Number')
    patient.occupation = get_attribute(person, 'Occupation')
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

  def create_from_form(params)
    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
    birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
    person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


    if person_params["gender"].to_s == "Female"
       person_params["gender"] = 'F'
    elsif person_params["gender"].to_s == "Male"
       person_params["gender"] = 'M'
    end

    person = Person.create(person_params)

    unless birthday_params.empty?
      if birthday_params["birth_year"] == "Unknown"
        set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
      else
        set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
      end
    end
    person.save
   
    person.names.create(names_params)
    person.addresses.create(address_params) unless address_params.empty? rescue nil

    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
      :value => params["occupation"]) unless params["occupation"].blank? rescue nil
 
    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
      :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil
 
    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
      :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil
 
    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
      :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

# TODO handle the birthplace attribute

    if (!patient_params.nil?)
      patient = person.create_patient

      patient_params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
      } if patient_params["identifiers"]

      # This might actually be a national id, but currently we wouldn't know
      #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
    end

    return person
  end

  def sex(person)
    value = nil
    if person.gender == "M"
      value = "Male"
    elsif person.gender == "F"
      value = "Female"
    end
    value
  end
  
  def person_search(params)
    people = search_by_identifier(params[:identifier])

    return people.first.id unless people.blank? || people.size > 1
    people = Person.find(:all, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
    "gender = ? AND \
     (person_name.given_name LIKE ? OR person_name_code.given_name_code LIKE ?) AND \
     (person_name.family_name LIKE ? OR person_name_code.family_name_code LIKE ?)",
    params[:gender],
    params[:given_name],
    (params[:given_name] || '').soundex,
    params[:family_name],
    (params[:family_name] || '').soundex
    ]) if people.blank?

    return people
  end
  
  def search_by_identifier(identifier)
    PatientIdentifier.find_all_by_identifier(identifier).map{|id| id.patient.person} unless identifier.blank? rescue nil
  end
  
  def set_birthdate_by_age(person, age, today = Date.today)
    person.birthdate = Date.new(today.year - age.to_i, 7, 1)
    person.birthdate_estimated = 1
  end
  
  def set_birthdate(person, year = nil, month = nil, day = nil)   
    raise "No year passed for estimated birthdate" if year.nil?

    # Handle months by name or number (split this out to a date method)    
    month_i = (month || 0).to_i
    month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    
    if month_i == 0 || month == "Unknown"
      person.birthdate = Date.new(year.to_i,7,1)
      person.birthdate_estimated = 1
    elsif day.blank? || day == "Unknown" || day == 0
      person.birthdate = Date.new(year.to_i,month_i,15)
      person.birthdate_estimated = 1
    else
      person.birthdate = Date.new(year.to_i,month_i,day.to_i)
      person.birthdate_estimated = 0
    end
  end
  
  def birthdate_formatted(person)
    if person.birthdate_estimated==1
      if person.birthdate.day == 1 and person.birthdate.month == 7
        person.birthdate.strftime("??/???/%Y")
      elsif person.birthdate.day == 15 
        person.birthdate.strftime("??/%b/%Y")
      elsif person.birthdate.day == 1 and person.birthdate.month == 1 
        person.birthdate.strftime("??/???/%Y")
      end
    else
      person.birthdate.strftime("%d/%b/%Y")
    end
  end
  
  def age_in_months(person, today = Date.today)
    years = (today.year - person.birthdate.year)
    months = (today.month - person.birthdate.month)
    (years * 12) + months
  end
  
  def get_attribute(person, attribute)
    PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        PersonAttributeType.find_by_name(attribute).id, person.id]).value rescue nil
  end

private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end
  
  def next_lab_encounter(patient , encounter = nil , session_date = Date.today)
    if encounter.blank?
      type = EncounterType.find_by_name('LAB ORDERS').id
      lab_order = Encounter.find(:first,
             :order => "encounter_datetime DESC,date_created DESC",
             :conditions =>["patient_id = ? AND encounter_type = ?",patient.id,type])
      return 'NO LAB ORDERS' if lab_order.blank?
      return
    end

    case encounter.name.upcase
      when 'LAB ORDERS' 
        type = EncounterType.find_by_name('SPUTUM SUBMISSION').id
        sputum_sub = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        return type if sputum_sub.blank?
        return sputum_sub 
      when 'SPUTUM SUBMISSION'
        type = EncounterType.find_by_name('LAB RESULTS').id
        lab_results = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        type = EncounterType.find_by_name('LAB ORDERS').id
        lab_order = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        return lab_order if lab_results.blank? and not lab_order.blank?
        return if lab_results.blank?
        return lab_results 
      when 'LAB RESULTS'
        type = EncounterType.find_by_name('SPUTUM SUBMISSION').id
        sputum_sub = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        return if sputum_sub.blank?
        return sputum_sub 
    end
  end
  
  def checks_if_vitals_are_need(patient , session_date, task , user_selected_activities)
    first_vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
                            :conditions =>["patient_id = ? AND encounter_type = ?",
                            patient.id,EncounterType.find_by_name('VITALS').id])


    if first_vitals.blank?
      encounter = Encounter.find(:first,:order => "encounter_datetime DESC",
                  :conditions =>["patient_id = ? AND encounter_type = ?",
                  patient.id,EncounterType.find_by_name('LAB ORDERS').id])
      
      sup_result = next_lab_encounter(patient , encounter, session_date)

      reception = Encounter.find(:first,:order => "encounter_datetime DESC",
                                 :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                 session_date.to_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id])

      if reception.blank? and not sup_result.blank?
        if user_selected_activities.match(/Manage TB Reception Visits/i)
          task.encounter_type = 'TB RECEPTION'
          task.url = "/encounters/new/tb_reception?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage TB Reception Visits/i)
          task.encounter_type = 'TB RECEPTION'
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      end if not (sup_result == 'NO LAB ORDERS')
    end

    if first_vitals.blank? and user_selected_activities.match(/Manage Vitals/i) 
      task.encounter_type = 'VITALS'
      task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
      return task
    elsif first_vitals.blank? and not user_selected_activities.match(/Manage Vitals/i) 
      task.encounter_type = 'VITALS'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    return if patient_tb_status(patient).match(/treatment/i) and not patient_hiv_status(patient).match(/Positive/i)

    vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
                            :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                            session_date.to_date,patient.id,EncounterType.find_by_name('VITALS').id])

    if vitals.blank? and user_selected_activities.match(/Manage Vitals/i) 
      task.encounter_type = 'VITALS'
      task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
      return task
    elsif vitals.blank? and not user_selected_activities.match(/Manage Vitals/i) 
      task.encounter_type = 'VITALS'
      task.url = "/patients/show/#{patient.id}"
      return task
    end 
  end

  def need_art_enrollment(task,patient,location,session_date,user_selected_activities,reason_for_art)
    return unless patient_hiv_status(patient).match(/Positive/i)

    enrolled_in_hiv_program = Concept.find(Observation.find(:first,
      :order => "obs_datetime DESC,date_created DESC", 
      :conditions => ["person_id = ? AND concept_id = ?",patient.id,
      ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil

    return unless enrolled_in_hiv_program == 'YES'

    #return if not reason_for_art.upcase == 'UNKNOWN' and not reason_for_art.blank?

    art_initial = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                             patient.id,EncounterType.find_by_name('ART_INITIAL').id],
                             :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

    if art_initial.blank? and user_selected_activities.match(/Manage HIV first visits/i)
      task.encounter_type = 'ART_INITIAL'
      task.url = "/encounters/new/art_initial?show&patient_id=#{patient.id}"
      return task
    elsif art_initial.blank? and not user_selected_activities.match(/Manage HIV first visits/i)
      task.encounter_type = 'ART_INITIAL'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    hiv_staging = Encounter.find(:first,:order => "encounter_datetime DESC",
                                 :conditions =>["patient_id = ? AND encounter_type = ?",
                                 patient.id,EncounterType.find_by_name('HIV STAGING').id])

    if hiv_staging.blank? and user_selected_activities.match(/Manage HIV staging visits/i)
      extended_staging_questions = get_global_property_value('use.extended.staging.questions')
      extended_staging_questions = extended_staging_questions.property_value == 'yes' rescue false
      task.encounter_type = 'HIV STAGING'
      task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}" if not extended_staging_questions
      task.url = "/encounters/new/llh_hiv_staging?show&patient_id=#{patient.id}" if extended_staging_questions
      return task
    elsif hiv_staging.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
      task.encounter_type = 'HIV STAGING'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    pre_art_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["patient_id = ? AND encounter_type = ?",
                                    patient.id,EncounterType.find_by_name('PART_FOLLOWUP').id])

    if pre_art_visit.blank? and user_selected_activities.match(/Manage pre ART visits/i)
      task.encounter_type = 'Pre ART visit'
      task.url = "/encounters/new/pre_art_visit?show&patient_id=#{patient.id}"
      return task
    elsif pre_art_visit.blank? and not user_selected_activities.match(/Manage pre ART visits/i)
      task.encounter_type = 'Pre ART visit'
      task.url = "/patients/show/#{patient.id}"
      return task
    end if reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?


    art_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
                               :conditions =>["patient_id = ? AND encounter_type = ?",
                               patient.id,EncounterType.find_by_name('ART VISIT').id])

    if art_visit.blank? and user_selected_activities.match(/Manage ART visits/i)
      task.encounter_type = 'ART VISIT'
      task.url = "/encounters/new/art_visit?show&patient_id=#{patient.id}"
      return task
    elsif art_visit.blank? and not user_selected_activities.match(/Manage ART visits/i)
      task.encounter_type = 'ART VISIT'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC",
                              :joins =>"INNER JOIN obs USING(encounter_id)",
                              :conditions =>["patient_id = ? AND encounter_type = ? AND concept_id = ?",
                              patient.id,EncounterType.find_by_name('TREATMENT').id,ConceptName.find_by_name('ARV regimen type').concept_id])

    prescribe_drugs = art_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe arvs this visit: Yes'.upcase rescue false

    if not prescribe_drugs 
      prescribe_drugs = pre_art_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false
    end

    if treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
      task.encounter_type = 'TREATMENT'
      task.url = "/regimens/new?patient_id=#{patient.id}"
      return task
    elsif treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
      task.encounter_type = 'TREATMENT'
      task.url = "/patients/show/#{patient.id}"
      return task
    end if prescribe_drugs
  end

  def get_national_id(patient, force = true)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier
    id
  end

  def get_remote_national_id(patient)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless id.blank?
    PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier
  end

  def get_national_id_with_dashes(patient, force = true)
    id = get_national_id(patient, force)
    id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
  end

end
