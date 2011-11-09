class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do 
    def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["DATE(encounter_datetime) = DATE(?)", encounter_date]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end
=begin
  def summary #
    #    verbiage << "Last seen #{visits.recent(1)}"
    verbiage = []
    verbiage << patient_programs.map{|prog| "Started #{prog.program.name.humanize} #{prog.date_enrolled.strftime('%b-%Y')}" rescue nil }
    verbiage << orders.unfinished.prescriptions.map{|presc| presc.to_s}
    verbiage.flatten.compact.join(', ') 
  end
=end

  def national_id(force = true)
    id = self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self).identifier
    id
  end

  def remote_national_id
    id = self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless id.blank?
    PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self).identifier
  end

  def national_id_with_dashes(force = true)
    id = self.national_id(force)
    id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
  end

  def get_identifier(type = 'National id')
    identifier_type = PatientIdentifierType.find_by_name(type)
    return if identifier_type.blank?
    identifiers = self.patient_identifiers.find_all_by_identifier_type(identifier_type.id)
    return if identifiers.blank?
    identifiers.map{|i|i.identifier}[0] rescue nil
  end

  def current_weight
    obs = person.observations.recent(1).question("WEIGHT (KG)").all
    obs.first.value_numeric rescue 0
  end
  
  def initial_weight
    obs = person.observations.old(1).question("WEIGHT (KG)").all
    obs.last.value_numeric rescue 0
  end
  
  def initial_height
    obs = person.observations.old(1).question("HEIGHT (CM)").all
    obs.last.value_numeric rescue 0
  end

  def initial_bmi
    obs = person.observations.old(1).question("BMI").all
    obs.last.value_numeric rescue nil
  end

  def min_weight
    WeightHeight.min_weight(person.gender, person.age_in_months).to_f
  end
  
  def max_weight
    WeightHeight.max_weight(person.gender, person.age_in_months).to_f
  end
  
  def min_height
    WeightHeight.min_height(person.gender, person.age_in_months).to_f
  end
  
  def max_height
    WeightHeight.max_height(person.gender, person.age_in_months).to_f
  end
  
  def given_arvs_before?
    self.orders.each{|order|
      drug_order = order.drug_order
      next if drug_order == nil
      next if drug_order.quantity == nil
      next unless drug_order.quantity > 0
      return true if drug_order.drug.arv?
    }
    false
  end

  def name
    "#{self.person.name}"
  end

  def self.appointment_dates(start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Patient.find(:all,
      :joins      => 'INNER JOIN obs ON patient.patient_id = obs.person_id',
      :conditions => ["DATE(obs.value_datetime) >= ? AND DATE(obs.value_datetime) <= ? AND obs.concept_id = ? AND obs.voided = 0", start_date.to_date, end_date.to_date, appointment_date_concept_id],
      :group      => "obs.person_id")

    appointments
  end

  def arv_number
    arv_number_id = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, arv_number_id).identifier rescue nil
  end

  def age_at_initiation(initiation_date = nil)
    patient = Person.find(self.id)
    return patient.age(initiation_date) unless initiation_date.nil?
  end

  def set_received_regimen(encounter,prescription)
    dispense_finish = true ; dispensed_drugs_inventory_ids = []
    
    prescription.orders.each do | order |
      next if not order.drug_order.drug.arv?
      dispensed_drugs_inventory_ids << order.drug_order.drug.id
      if (order.drug_order.amount_needed > 0)
        dispense_finish = false
      end
    end

    return unless dispense_finish
    return if dispensed_drugs_inventory_ids.blank?

    regimen_id = ActiveRecord::Base.connection.select_all <<EOF
SELECT r.concept_id ,
(SELECT COUNT(t3.regimen_id) FROM regimen_drug_order t3 
WHERE t3.regimen_id = t.regimen_id GROUP BY t3.regimen_id) as c
FROM regimen_drug_order t, regimen r  
WHERE t.drug_inventory_id IN (#{dispensed_drugs_inventory_ids.join(',')})
AND r.regimen_id = t.regimen_id
GROUP BY r.concept_id
HAVING c = #{dispensed_drugs_inventory_ids.length}
EOF
    
    regimen_prescribed = regimen_id.first['concept_id'].to_i rescue ConceptName.find_by_name('UNKNOWN ANTIRETROVIRAL DRUG').concept_id
    
    if (Observation.find(:first,:conditions => ["person_id = ? AND encounter_id = ? AND concept_id = ?",
            self.id,encounter.id,ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT').concept_id])).blank?
      regimen_value_text = Concept.find(regimen_prescribed).shortname rescue nil
      if regimen_value_text.blank?
        regimen_value_text = ConceptName.find_by_concept_id(regimen_prescribed).name rescue nil
      end
      return if regimen_value_text.blank?
      obs = Observation.new(
        :concept_name => "ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT",
        :person_id => self.id,
        :encounter_id => encounter.id,
        :value_text => regimen_value_text,
        :value_coded => regimen_prescribed,
        :obs_datetime => encounter.encounter_datetime)
      obs.save
      return obs.value_text 
    end
  end

  def gender
    self.person.sex
  end

  def last_art_visit_before(date = Date.today)
    art_encounters = ['ART_INITIAL','HIV RECEPTION','VITALS','HIV STAGING','ART VISIT','ART ADHERENCE','TREATMENT','DISPENSING']
    art_encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",art_encounters]).map{|e|e.encounter_type_id}
    Encounter.find(:first,
      :conditions => ["DATE(encounter_datetime) < ? AND patient_id = ? AND encounter_type IN (?)",date,
        self.id,art_encounter_type_ids],
      :order => 'encounter_datetime DESC').encounter_datetime.to_date rescue nil
  end
  
  def drug_given_before(date = Date.today)
    encounter_type = EncounterType.find_by_name('TREATMENT')
    Encounter.find(:first,
      :joins => 'INNER JOIN orders ON orders.encounter_id = encounter.encounter_id
               INNER JOIN drug_order ON orders.order_id = orders.order_id', 
      :conditions => ["quantity IS NOT NULL AND encounter_type = ? AND
               encounter.patient_id = ? AND DATE(encounter_datetime) < ?",
        encounter_type.id,self.id,date.to_date],
        :order => 'encounter_datetime DESC,date_created DESC').orders rescue []
  end

  def prescribe_arv_this_visit(date = Date.today)
    encounter_type = EncounterType.find_by_name('ART VISIT')
    yes_concept = ConceptName.find_by_name('YES').concept_id
    refer_concept = ConceptName.find_by_name('PRESCRIBE ARVS THIS VISIT').concept_id
    refer_patient = Encounter.find(:first,
      :joins => 'INNER JOIN obs USING (encounter_id)',
      :conditions => ["encounter_type = ? AND concept_id = ? AND person_id = ? AND value_coded = ? AND DATE(obs_datetime) = ?",
        encounter_type.id,refer_concept,self.id,yes_concept,date.to_date],
      :order => 'encounter_datetime DESC,date_created DESC')
    return false if refer_patient.blank?
    return true
  end

  def number_of_days_to_add_to_next_appointment_date(date = Date.today)
    #because a dispension/pill count can have several drugs,we pick the drug with the lowest pill count
    #and we also make sure the drugs in the pill count/Adherence encounter are the same as the one in Dispension encounter
    
    concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
    encounter_type = EncounterType.find_by_name('ART ADHERENCE')
    adherence = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,self.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')
    return 0 if adherence.blank?
    concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    encounter_type = EncounterType.find_by_name('DISPENSING')
    drug_dispensed = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,self.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')

    #check if what was dispensed is what was counted as remaing pills
    return 0 unless (drug_dispensed.map{| d | d.value_drug } - adherence.map{|a|a.order.drug_order.drug_inventory_id}) == []
   
    #the folliwing block of code picks the drug with the lowest pill count
    count_drug_count = []
    (adherence).each do | adh |
      unless count_drug_count.blank?
        if adh.value_numeric < count_drug_count[1]
          count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric]
        end
      end
      count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric] if count_drug_count.blank?
    end

    #from the drug dispensed on that day,we pick the drug "plus it's daily dose" that match the drug with the lowest pill count    
    equivalent_daily_dose = 1
    (drug_dispensed).each do | dispensed_drug |
      drug_order = dispensed_drug.order.drug_order
      if count_drug_count[0] == drug_order.drug_inventory_id
        equivalent_daily_dose = drug_order.equivalent_daily_dose
      end
    end
    (count_drug_count[1] / equivalent_daily_dose).to_i
  end

  def art_start_date
    date = ActiveRecord::Base.connection.select_value <<EOF
SELECT patient_start_date(#{self.id})
EOF
    return date.to_date rescue nil
  end

  def art_patient?
    program_id = Program.find_by_name('HIV PROGRAM').id
    enrolled = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,self.id]).blank?
    return true unless enrolled 
    false
  end

  def art_guardian
    person_id = Relationship.find(:first,:order => "date_created DESC",
      :conditions =>["person_a = ?",self.person.id]).person_b rescue nil
    Person.find(person_id).name rescue nil
  end

  def self.art_info_for_remote(national_id)

    patient = Person.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}
    
    if patient.art_patient?
      clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','ART_INITIAL']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'
      

      art_start_date = patient.art_start_date.strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

      program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'
      
      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
        'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => patient.arv_number
      }
    end

    results["person"] = result_hash
    return results
  end

  def set_new_filing_number
    ActiveRecord::Base.transaction do
      global_property_value = GlobalProperty.find_by_property("filing.number.limit").property_value rescue '10'

      filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing number")
      archive_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")

      next_filing_number = PatientIdentifier.next_filing_number('Filing number')
      if (next_filing_number[5..-1].to_i >= global_property_value.to_i)
        encounter_type_name = ['REGISTRATION','VITALS','ART_INITIAL','ART VISIT',
          'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
        encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id} 
    
        all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ?",
            filing_number_identifier_type.id],:group=>"patient_id")
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
              filing_number_identifier_type.id],
            :group=>"patient_id",:order => "identifier DESC").patient rescue nil
        end
      end

      if self.get_identifier('Archived filing number')
        #voids the record- if patient has a dormant filing number
        current_archive_filing_numbers = self.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == archive_identifier_type.id and identifier.voided
        }.compact
        current_archive_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "patient assign new active filing number"
          filing_number.voided_by = User.current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      end
     
      unless patient_to_be_archived.blank?
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = self.id
        filing_number.identifier = patient_to_be_archived.get_identifier('Filing Number')
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save

        current_active_filing_numbers = patient_to_be_archived.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == filing_number_identifier_type.id and not identifier.voided
        }.compact
        current_active_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "Archived - filing number given to:#{self.id}"
          filing_number.voided_by = User.current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      else
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = self.id
        filing_number.identifier = next_filing_number
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save
      end 
      true
    end
  end

  def set_filing_number
    next_filing_number = PatientIdentifier.next_filing_number # gets the new filing number! 
    # checks if the the new filing number has passed the filing number limit...
    # move dormant patient from active to dormant filing area ... if needed
    Patient.next_filing_number_to_be_archived(self,next_filing_number) 
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
        filing_number.identifier = patient_to_be_archived.get_identifier('Filing Number')
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

  def patient_to_be_archived
    active_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier 
      WHERE voided = 1 AND identifier_type = ? AND void_reason = ? ORDER BY date_created DESC",
        active_identifier_type.id,"Archived - filing number given to:#{self.id}"]).first.patient rescue nil
  end

  def old_filing_number(type = 'Filing Number')
    identifier_type = PatientIdentifierType.find_by_name(type)
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier 
      WHERE patient_id = ?
      AND identifier_type = ? 
      AND voided = 1
      ORDER BY date_created DESC
      LIMIT 1",self.id,identifier_type.id]).first.identifier rescue nil
  end

  def self.printing_filing_number_label(number=nil)
    return number[5..5] + " " + number[6..7] + " " + number[8..-1] unless number.nil?
  end

  def self.printing_message(new_patient , archived_patient , creating_new_filing_number_for_patient = false)
    arv_code = Location.current_arv_code
    new_patient_name = new_patient.name
    new_filing_number = self.printing_filing_number_label(new_patient.get_identifier('Filing Number'))
    old_archive_filing_number = self.printing_filing_number_label(new_patient.old_filing_number('Archived filing number'))
    unless archived_patient.blank?
      old_active_filing_number = self.printing_filing_number_label(archived_patient.old_filing_number)
      new_archive_filing_number = self.printing_filing_number_label(archived_patient.get_identifier('Archived filing number'))
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
  <td class = 'filing_instraction'>#{archived_patient.name}</td>
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
  <td class = 'filing_instraction'>#{archived_patient.name}</td>
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

  def id_identifiers
    identifier_type = ["Legacy Pediatric id","National id","Legacy National id"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_type]
    ).collect{| type |type.id }
    
    PatientIdentifier.find(:all,
      :conditions=>["patient_id=? AND identifier_type IN (?)",
        self.id,identifier_types]).collect{| i | i.identifier }
  end

  def self.edit_mastercard_attribute(attribute_name)
    edit_page = attribute_name
  end

  def self.save_mastercard_attribute(params)
    patient = Patient.find(params[:patient_id])
    case params[:field]
    when 'arv_number'
      type = params['identifiers'][0][:identifier_type]
      #patient = Patient.find(params[:patient_id])
      patient_identifiers = PatientIdentifier.find(:all,
        :conditions => ["voided = 0 AND identifier_type = ? AND patient_id = ?",type.to_i,patient.id])

      patient_identifiers.map{|identifier|
        identifier.voided = 1
        identifier.void_reason = "given another number"
        identifier.date_voided  = Time.now()
        identifier.voided_by = User.current_user.id
        identifier.save
      }

      identifier = params['identifiers'][0][:identifier].strip
      if identifier.match(/(.*)[A-Z]/i).blank?
        params['identifiers'][0][:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{identifier}"
      end
      patient.patient_identifiers.create(params[:identifiers])
    when "name"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "age"
      birthday_params = params[:person]

      if !birthday_params.empty?
        if birthday_params["birth_year"] == "Unknown"
          patient.person.set_birthdate_by_age(birthday_params["age_estimate"])
        else
          patient.person.set_birthdate(birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
        end
        patient.person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
        patient.person.save
      end
    when "sex"
      gender ={"gender" => params[:gender].to_s}
      patient.person.update_attributes(gender) if !gender.empty?
    when "location"
      location = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(location) if location
    when "occupation"
      attribute = params[:person][:attributes]
      occupation_attribute = PersonAttributeType.find_by_name("Occupation")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, occupation_attribute.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:occupation].to_s})
      end
    when "guardian"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      Person.find(params[:guardian_id].to_s).names.first.update_attributes(names_params) rescue '' if names_params
    when "address"
      address2 = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(address2) if address2
    when "ta"
      county_district = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(county_district) if county_district
    end
  end

  def eid_number
    eid_number_id = PatientIdentifierType.find_by_name('EID Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, eid_number_id).identifier rescue nil
  end

  def filing_number
    filing_number = PatientIdentifierType.find_by_name('Filing Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, filing_number).identifier rescue nil
  end

  def pre_art_number
    pre_art_number_id = PatientIdentifierType.find_by_name('Pre ART Number (Old format)').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, pre_art_number_id).identifier rescue nil
  end
  
  def appointment_dates(start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Observation.find(:all,
      :conditions => ["DATE(obs.value_datetime) >= ? AND DATE(obs.value_datetime) <= ? AND " +
          "obs.concept_id = ? AND obs.voided = 0 AND obs.person_id = ?", start_date.to_date,
        end_date.to_date, appointment_date_concept_id, self.id])

    appointments
  end

  def reason_for_art_eligibility
    reasons = self.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue nil
  end

  def child_bearing_female?
    (gender == "Female" && self.person.age >= 9 && self.person.age <= 45) ? true : false
  end
  #pb: bug-2677 Added the block below to check if the patient was transfered in
  def transfer_in?
    patient_transfer_in = self.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return false if patient_transfer_in.blank?
    return true
  end

  def transfer_in_date?
    patient_transfer_in = self.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return patient_transfer_in.each{|datetime| return datetime.obs_datetime  if datetime.obs_datetime}
  end
  
  #from TB ART TO BART
  
  def tb_status
    Concept.find(Observation.find(:first, 
    :order => "obs_datetime DESC,date_created DESC",
    :conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL", self.id, 
    ConceptName.find_by_name("TB STATUS").concept_id]).value_coded).fullname rescue "UNKNOWN"
  end
  
=begin # could not find where it is being used DFFI
  def is_first_visit?
    clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",
                          'ART ADHERENCE','DISPENSING','ART_INITIAL', "LAB ORDERS",
                          "LAB RESULTS","HIV RECEPTION","SPUTUM SUBMISSION",
                          "TB RECEPTION","TB REGISTRATION","TB TREATMENT",
                          "TB_FOLLOWUP"
                          ]
    current_date = Time.now.strftime("%d-%b-%Y")

    clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
    first_encounter_date = self.encounters.find(:first,
      :order => 'encounter_datetime',
      :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Unknown'

    return true if first_encounter_date == 'Unknown'
    return true if current_date == first_encounter_date
    return false if current_date > first_encounter_date

  end
=end
	def residence
		patient = Person.find(self.id)
		return patient.person.addresses.first.city_village
	end
  
	def age
		patient = Person.find(self.id)
		return patient.age
	end 

=begin # could not find a place where the method below is being used, therefore just disabled it
# for further investigation
  def sputum_results_given
   given_results = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("GIVE LAB RESULTS").id,self.id]).observations.map{|o| o if self.recent_sputum_orders.collect{|observation| observation.accession_number}.include?(o.accession_number)} rescue []
  end
=end
end
