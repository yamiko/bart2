module PatientService
  
  def self.current_treatment_encounter(patient, date = Time.now(), provider = user_person_id)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",date.to_date,type.id])
    encounter ||= patient.encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)
  end

  def self.recent_sputum_submissions(patient_id)
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))",patient_id, ConceptName.find_by_name('Sputum submission').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3) rescue []
  end

  def self.recent_sputum_results(patient_id)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    obs = Observation.find(:all, :conditions => ["person_id = ? AND concept_id IN (?)", patient_id, sputum_concept_ids], :order => "obs_datetime desc", :limit => 3)
  end

  def self.sputum_orders_without_submission(patient_id)
    recent_sputum_orders(patient_id).collect{|order| order unless Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?", patient_id, Concept.find_by_name("Sputum submission")]).map{|o| o.accession_number}.include?(order.accession_number)}.compact #rescue []
  end

  def self.recent_sputum_orders(patient_id)
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", patient_id, ConceptName.find_by_name('Tests ordered').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)
  end

  def self.hiv_test_date(patient_id)
    test_date = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", patient_id, ConceptName.find_by_name("HIV test date").concept_id]).value_datetime rescue nil
    return test_date
  end

  def self.months_since_last_hiv_test(patient_id)
    #this can be done better
    session_date = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", patient_id, ConceptName.find_by_name("HIV test date").concept_id]).obs_datetime rescue Date.today

    today =  session_date
    hiv_test_date = hiv_test_date(patient_id)
    months = (today.year * 12 + today.month) - (hiv_test_date.year * 12 + hiv_test_date.month) rescue nil
    return months
  end

  #also referenced in different methods in application
  def self.patient_hiv_status(patient)
    status = Concept.find(Observation.find(:first,
    :order => "obs_datetime DESC,date_created DESC",
    :conditions => ["value_coded IS NOT NULL AND person_id = ? AND concept_id = ?", patient.id,
    ConceptName.find_by_name("HIV STATUS").concept_id]).value_coded).fullname rescue "UNKNOWN"
    if status.upcase == 'UNKNOWN'
      return patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') ? 'Positive' : status
    end
    return status
  end

  def self.patient_is_child?(patient)
   return get_patient_attribute_value(patient, "age") <= 14 unless get_patient_attribute_value(patient, "age").nil?
   return false
 end

 def self.get_patient_attribute_value(patient, attribute_name)
 	
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

 def self.drug_given_before(patient, date = Date.today)
    encounter_type = EncounterType.find_by_name('TREATMENT')
    Encounter.find(:first,
      :joins => 'INNER JOIN orders ON orders.encounter_id = encounter.encounter_id
               INNER JOIN drug_order ON orders.order_id = orders.order_id',
      :conditions => ["quantity IS NOT NULL AND encounter_type = ? AND
               encounter.patient_id = ? AND DATE(encounter_datetime) < ?",
        encounter_type.id,patient.id,date.to_date],
        :order => 'encounter_datetime DESC,date_created DESC').orders rescue []
  end

 def self.reason_for_art_eligibility(patient)
    reasons = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue nil
 end

 def self.patient_appointment_dates(patient, start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Observation.find(:all,
      :conditions => ["DATE(obs.value_datetime) >= ? AND DATE(obs.value_datetime) <= ? AND " +
          "obs.concept_id = ? AND obs.voided = 0 AND obs.person_id = ?", start_date.to_date,
        end_date.to_date, appointment_date_concept_id, patient.id])

    appointments
  end

  def self.get_patient_identifier(patient, identifier_type)
    patient_identifier_type_id = PatientIdentifierType.find_by_name(identifier_type).patient_identifier_type_id
    patient_identifier = PatientIdentifier.find(:first, :select => "identifier",
                                                :conditions  =>["patient_id = ? and identifier_type = ?", patient.id, patient_identifier_type_id],
                                                :order => "date_created DESC" ).identifier rescue nil
    return patient_identifier
  end

  def self.get_patient(person)
    patient = Mastercard.new()
    patient.person_id = person.id
    patient.patient_id = person.patient.id
    patient.arv_number = get_patient_identifier(person.patient, 'ARV Number')
    patient.address = person.addresses.first.city_village
    patient.national_id = get_patient_identifier(person.patient, 'National id')    
	patient.national_id_with_dashes = get_national_id_with_dashes(person.patient)
    patient.name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
    patient.sex = sex(person)
    patient.age = person.age
    patient.age_in_months = age_in_months(person)
    patient.dead = person.dead
    patient.birth_date = birthdate_formatted(person)
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

  def self.sex(person)
    value = nil
    if person.gender == "M"
      value = "Male"
    elsif person.gender == "F"
      value = "Female"
    end
    value
  end

  def self.birthdate_formatted(person)
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
  
  def self.age_in_months(person, today = Date.today)
    years = (today.year - person.birthdate.year)
    months = (today.month - person.birthdate.month)
    (years * 12) + months
  end

  def self.get_national_id_with_dashes(patient, force = true)
    id = get_national_id(patient, force)
    id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
  end
  
  def self.get_national_id(patient, force = true)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier
    id
  end

  def self.get_attribute(person, attribute)
    PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        PersonAttributeType.find_by_name(attribute).id, person.id]).value rescue nil
  end

  def self.get_remote_national_id(patient)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless id.blank?
    PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier
  end

  def self.patient_national_id_label(patient)
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

  def self.patient_printing_message(new_patient , archived_patient , creating_new_filing_number_for_patient = false)
    arv_code = Location.current_arv_code
    new_patient_name = new_patient.person.name
    new_filing_number = patient_printing_filing_number_label(get_patient_identifier(new_patient, 'Filing Number'))
    old_archive_filing_number = patient_printing_filing_number_label(old_filing_number(new_patient, 'Archived filing number'))
    unless archived_patient.blank?
      old_active_filing_number = patient_printing_filing_number_label(old_filing_number(archived_patient))
      new_archive_filing_number = patient_printing_filing_number_label(get_patient_identifier(archived_patient, 'Archived filing number'))
    end

    if new_patient and archived_patient and creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th style="text-align:left;">Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Active → Dormant</td>
  <td class = 'filing_instraction'>#{archived_patient.person.name}</td>
  <td class = 'old_label'>#{old_active_filing_number}</td>
  <td class='new_label'>#{new_archive_filing_number}</td>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th>&nbsp;</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'filing_instraction'>&nbsp;</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and archived_patient and not creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th style="text-align:left;">Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Active → Dormant</td>
  <td class = 'filing_instraction'>#{archived_patient.person.name}</td>
  <td class = 'old_label'>#{old_active_filing_number}</td>
  <td class='new_label'>#{new_archive_filing_number}</td>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and not creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th>Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    end

    return table
  end

  def self.patient_printing_filing_number_label(number=nil)
    return number[5..5] + " " + number[6..7] + " " + number[8..-1] unless number.nil?
  end

  def self.set_patient_filing_number(patient) #changed from set_filing_number after being moved from patient model
    next_filing_number = PatientIdentifier.next_filing_number # gets the new filing number!
    # checks if the the new filing number has passed the filing number limit...
    # move dormant patient from active to dormant filing area ... if needed
    next_filing_number_to_be_archived(patient, next_filing_number)
  end

  def self.next_filing_number_to_be_archived(current_patient , next_filing_number)
    ActiveRecord::Base.transaction do
      global_property_value = GlobalProperty.find_by_property("filing.number.limit").property_value rescue '10000'
      active_filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
      dormant_filing_number_identifier_type = PatientIdentifierType.find_by_name('Archived filing number')

      if (next_filing_number[5..-1].to_i >= global_property_value.to_i)
        encounter_type_name = ['REGISTRATION','VITALS','ART_INITIAL','ART VISIT',
          'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
        encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id}

        all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ?",
            PatientIdentifierType.find_by_name("Filing Number").id],:group=>"patient_id")
        patient_ids = all_filing_numbers.collect{|i|i.patient_id}
        patient_to_be_archived = Encounter.find_by_sql(["
          SELECT patient_id, MAX(encounter_datetime) AS last_encounter_id
          FROM encounter
          WHERE patient_id IN (?)
          AND encounter_type IN (?)
          GROUP BY patient_id
          ORDER BY last_encounter_id
          LIMIT 1",patient_ids,encounter_type_ids]).first.patient rescue nil
        if patient_to_be_archived.blank?
          patient_to_be_archived = PatientIdentifier.find(:last,:conditions =>["identifier_type = ?",
              PatientIdentifierType.find_by_name("Filing Number").id],
            :group=>"patient_id",:order => "identifier DESC").patient rescue nil
        end
      end

      if patient_to_be_archived
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = patient_to_be_archived.id
        filing_number.identifier_type = dormant_filing_number_identifier_type.id
        filing_number.identifier = PatientIdentifier.next_filing_number("Archived filing number")
        filing_number.save

        #assigning "patient_to_be_archived" filing number to the new patient
        filing_number= PatientIdentifier.new()
        filing_number.patient_id = current_patient.id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = get_patient_identifier(patient_to_be_archived, 'Filing Number')
        filing_number.save

        #void current filing number
        current_filing_numbers =  PatientIdentifier.find(:all,:conditions=>["patient_id=? AND identifier_type = ?",
            patient_to_be_archived.id,PatientIdentifierType.find_by_name("Filing Number").id])
        current_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.voided_by = User.current_user.id
          filing_number.void_reason = "Archived - filing number given to:#{current_patient.id}"
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      else
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = current_patient.id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = next_filing_number
        filing_number.save
      end
    end

    true
  end

  def self.patient_age_at_initiation(patient, initiation_date = nil)
    return patient.person.age(initiation_date) unless initiation_date.nil?
  end

  def self.art_patient?(patient)
    program_id = Program.find_by_name('HIV PROGRAM').id
    enrolled = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id]).blank?
    return true unless enrolled
    false
  end

  def self.patient_art_start_date(patient_id)
    date = ActiveRecord::Base.connection.select_value <<EOF
SELECT patient_start_date(#{patient_id})
EOF
    return date.to_date rescue nil
  end

  def self.old_filing_number(patient, type = 'Filing Number')
    identifier_type = PatientIdentifierType.find_by_name(type)
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier
      WHERE patient_id = ?
      AND identifier_type = ?
      AND voided = 1
      ORDER BY date_created DESC
      LIMIT 1",patient.id,identifier_type.id]).first.identifier rescue nil
  end
end
