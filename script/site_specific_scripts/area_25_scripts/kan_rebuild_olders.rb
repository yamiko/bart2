#script to rebuild the obs table

def init
  if ARGV[0].blank? or ARGV[1].blank? 
     puts "Usage: "
     puts 'script/runner script start_date end_date'
     puts 'start date format : "YYYY-mm-dd"'
     puts 'end date format   : "YYYY-mm-dd"'
     puts 'Rebuld terminated  .........'
     return
  end
  begin
     Date.parse(ARGV[0])
     Date.parse(ARGV[1])
     if ARGV[1] >= ARGV[0]
       get_orders(ARGV[0], ARGV[1])
       create_program(ARGV[0])
     else
       puts "End date less than start date"
     end
  rescue ArgumentError
    puts "Wrong dates entered"
  end
end

def get_orders(start_date, end_date)
   start_date = start_date.to_date.strftime('%Y-%m-%d')
    end_date = end_date.to_date.strftime('%Y-%m-%d')
   ordered = Observation.find_by_sql("SELECT * FROM obs
                    WHERE order_id IS NOT NULL AND DATE(obs_datetime) >= '#{start_date}'
                     AND DATE(obs_datetime) <= '#{end_date}'
                    AND voided = 0 ORDER BY order_id ASC")
   puts "Orders will be built from #{start_date} to #{ordered.last.obs_datetime.strftime('%Y-%m-%d')}"
   x = 0
   ordered.each{|order|
  
      related = Order.find_by_sql("
        SELECT * FROM orders WHERE order_id = #{order.order_id}")
      if related.blank?
        x += 1
        drug_order = DrugOrder.find(order.order_id)
        quantity = drug_order.quantity
        dose = drug_order.dose
        daily = drug_order.equivalent_daily_dose
        duration = quantity / (dose * daily)
        concept_id = drug_order.drug.concept_id
        orderer = order.creator
        encounter_id = order.encounter_id
        start_date = order.obs_datetime.to_date
        auto_expire_date = start_date + duration.to_i.days
        patient_id = order.person_id
        creator = order.creator
        voided = 0
        uuid =  ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']
        puts "#{order.order_id}"

        new_order  = Order.create(
        :order_id => order.order_id,
        :order_type_id => 1,
        :concept_id => concept_id,
        :orderer => orderer,
        :patient_id => patient_id,
        :start_date => start_date,
        :auto_expire_date => auto_expire_date,
        :encounter_id => encounter_id,
        :creator => creator,
        :voided => voided,
        :uuid => uuid)
        puts "#{x} : #{order.order_id} with concept #{concept_id} to build"
        
      end
   }


 # puts "#{all_ids}"
end

def create_program(start_date)
  art_patients = []
    Encounter.find_by_sql("
    SELECT distinct(patient_id) FROM encounter e
    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
    WHERE patient_id NOT IN (SELECT patient_id FROM patient_program
    WHERE voided = 0) AND encounter_datetime > '#{start_date}'
    AND  et.name IN ('HIV CLINIC REGISTRATION','HIV RECEPTION',
    'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE')
    ").each{|patient|
    art_patients << patient.patient_id}

  ccc_patients = []
  Encounter.find_by_sql("
    SELECT distinct(patient_id) FROM encounter e
    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
    WHERE patient_id NOT IN (SELECT patient_id FROM patient_program
    WHERE voided = 0) AND encounter_datetime > '#{start_date}'
    AND  et.name IN (  'EPILEPSY CLINIC VISIT','FAMILY MEDICAL HISTORY','MEDICAL HISTORY',
    'GENERAL HEALTH','SOCIAL HISTORY','LAB RESULTS','DIABETES HYPERTENSION INITIAL VISIT'
    'ASTHMA MEASURE','COMPLICATIONS','ASSESSMENT')
    ").each{|patient|
     ccc_patients << patient.patient_id}

  art_program = Program.find_by_name("HIV program").id
  ccc_program  = Program.find_by_name("Chronic Care program").id
  all_ids = (art_patients + ccc_patients).sort
  program = 0

  (all_ids || []).each{|patient|

     program = art_program
     if art_patients.include?(patient)
   first_encounter =   Encounter.find_by_sql("
    SELECT * FROM encounter e
    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
    WHERE patient_id NOT IN (SELECT patient_id FROM patient_program
    WHERE voided = 0) AND encounter_datetime > '#{start_date}'
    AND  et.name IN ('HIV CLINIC REGISTRATION','HIV RECEPTION',
    'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE')
    AND e.patient_id = #{patient}
    ORDER BY e.encounter_id DESC LIMIT 1").first

       patient_program = PatientProgram.create(
                :patient_id => patient,
                :program_id => program,
                :date_enrolled => first_encounter.encounter_datetime,
                :creator => first_encounter.creator
              )
                   puts "ART program created for #{patient}"
                   rebuild_art_states(patient, patient_program.patient_program_id,  start_date)
     end
     program = ccc_program
     if ccc_patients.include?(patient)
       first_encounter =   Encounter.find_by_sql("
        SELECT * FROM encounter e
        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
        WHERE patient_id NOT IN (SELECT patient_id FROM patient_program
        WHERE voided = 0) AND encounter_datetime > '#{start_date}'
        AND  et.name IN (  'EPILEPSY CLINIC VISIT','FAMILY MEDICAL HISTORY','MEDICAL HISTORY',
        'GENERAL HEALTH','SOCIAL HISTORY','LAB RESULTS','DIABETES HYPERTENSION INITIAL VISIT'
        'ASTHMA MEASURE','COMPLICATIONS','ASSESSMENT')
         AND e.patient_id = #{patient}
        ORDER BY e.encounter_id DESC LIMIT 1").first

        patient_program = PatientProgram.create(
                :patient_id => patient,
                :program_id => program,
                :date_enrolled => first_encounter.encounter_datetime,
                :creator => first_encounter.creator
              )
              puts "Chronic care program created for #{patient}"
                rebuild_ccc_states(patient, patient_program.patient_program_id, start_date)
     end

  }

end

def rebuild_art_states(id, program, start_date)
   on_arvs = Observation.find_by_sql("
     SELECT pp.patient_program_id, 7 AS state, DATE(obs1.obs_datetime) AS date, pp.creator
      FROM patient_program pp
      INNER JOIN (SELECT obs.person_id, MIN(obs.obs_datetime) AS obs_datetime FROM drug_order d
          LEFT JOIN orders o ON d.order_id = o.order_id
          LEFT JOIN obs ON d.order_id = obs.order_id
          WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug
          WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085))
              AND quantity > 0
              AND obs.voided = 0
              AND o.voided = 0
          AND DATE(obs.obs_datetime) >= '#{start_date}'
          AND obs.person_id = #{id}
          GROUP BY obs.person_id) obs1 ON pp.patient_id = obs1.person_id AND pp.program_id = 1
      GROUP BY pp.patient_id, DATE(obs1.obs_datetime)")
 (on_arvs || []).each{|arv|
      PatientState.create(
      :patient_program_id => program,
      :state => arv.state,
      :start_date => arv.date.to_date.strftime('%Y-%m-%d'),
      :creator => arv.creator)
 }

  died = PatientProgram.find_by_sql("
              SELECT pp.patient_program_id, 3 AS state, MIN(o.obs_datetime) AS date, o.creator
              FROM obs o LEFT JOIN patient_program pp ON o.person_id = pp.patient_id 
              AND pp.program_id = 1
              WHERE  o.value_coded = 1742 AND o.voided = 0
               AND DATE(o.obs_datetime) >= '#{start_date}'
          AND o.person_id = #{id}
              GROUP BY o.person_id")
      (died || []).each{|dead|
      PatientState.create(
      :patient_program_id => program,
      :state => dead.state,
      :start_date => dead.date.to_date.strftime('%Y-%m-%d'),
      :creator => dead.creator)
      }

   stopped = PatientProgram.find_by_sql("
    SELECT pp.patient_program_id, 6 AS state, o.obs_datetime AS date, o.creator
    FROM obs o LEFT JOIN patient_program pp ON o.person_id = pp.patient_id AND pp.program_id = 1
    WHERE  o.value_coded = 1579 AND o.voided = 0
    AND DATE(o.obs_datetime) >= '#{start_date}'
    AND o.person_id = #{id}
    GROUP BY DATE(o.obs_datetime), o.person_id ")

    (stopped || []).each{|stop|
      PatientState.create(
      :patient_program_id => program,
      :state => stop.state,
      :start_date => stop.date.to_date.strftime('%Y-%m-%d'),
      :creator => stop.creator)
      }

    transfer = PatientProgram.find_by_sql("
      SELECT pp.patient_program_id, 2 AS state, o.obs_datetime AS date, o.creator
      FROM obs o LEFT JOIN patient_program pp ON o.person_id = pp.patient_id AND pp.program_id = 1
      WHERE o.concept_id = 3003 AND o.voided = 0
       AND DATE(o.obs_datetime) >= '#{start_date}'
    AND o.person_id = #{id}
      GROUP BY DATE(o.obs_datetime), o.person_id")
         (transfer || []).each{|out|
      PatientState.create(
      :patient_program_id => program,
      :state => out.state,
      :start_date => out.date.to_date.strftime('%Y-%m-%d'),
      :creator => out.creator)
      }

      rebuild_program_states(program, id)
end

def rebuild_ccc_states(id, program, start_date)
     states = {"PATIENT DEFAULTED"=>154, "TREATMENT STOPPED"=>158, "PATIENT TRANSFERRED OUT"=>84, "ALIVE"=>157, "ON TREATMENT"=>83, "DISCHARGED"=>86, "PATIENT DIED"=>85}
      outcome = PatientProgram.find_by_sql("
      SELECT pp.patient_program_id, o.value_coded,  o.obs_datetime AS date, o.creator
      FROM obs o LEFT JOIN patient_program pp ON o.person_id = pp.patient_id AND pp.program_id = 10
      WHERE o.concept_id = 6538 AND o.voided = 0
       AND DATE(o.obs_datetime) >= '#{start_date}'
    AND o.person_id = #{id}
      GROUP BY DATE(o.obs_datetime), o.person_id")

         (outcome || []).each{|out|
           concept =  ConceptName.find_by_concept_name_id(out.value_coded).name.upcase
      PatientState.create(
      :patient_program_id => program,
      :state => states[concept],
      :start_date => out.date.to_date.strftime('%Y-%m-%d'),
      :creator => out.creator)
      }
      rebuild_ccc_program_states(program, id)
end

 def self.date_dispensation_date_after(patient, date_after)

		hypertensition_medication_id  = Concept.find_by_name("HYPERTENSION MEDICATION").id
		diabetes_id                   = Concept.find_by_name("DIABETES MEDICATION").id
    asthma_id             = Concept.find_by_name("ASTHMA MEDICATION").id
    epilepsy_id             = Concept.find_by_name("EPILEPSY MEDICATION").id
    
    start_date = ActiveRecord::Base.connection.select_value "
    SELECT DATE(obs.obs_datetime) AS obs_datetime
    FROM drug_order d
        LEFT JOIN orders o ON d.order_id = o.order_id
        LEFT JOIN obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set IN (#{hypertensition_medication_id}, #{asthma_id},#{diabetes_id}, #{epilepsy_id})))
        AND quantity > 0
        AND obs.voided = 0
        AND o.voided = 0
        AND obs.person_id = #{patient.id}
        AND DATE(obs.obs_datetime) > DATE(#{date_after})
    ORDER BY obs.obs_datetime ASC
    LIMIT 1
    "
    start_date.to_date rescue nil

  end

  def first_dispensation(patient)

		hypertensition_medication_id  = Concept.find_by_name("HYPERTENSION MEDICATION").id
		diabetes_id                   = Concept.find_by_name("DIABETES MEDICATION").id
    asthma_id             = Concept.find_by_name("ASTHMA MEDICATION").id
    epilepsy_id             = Concept.find_by_name("EPILEPSY MEDICATION").id

    start_date = ActiveRecord::Base.connection.select_value "
    SELECT DATE(obs.obs_datetime) AS obs_datetime
    FROM drug_order d
        LEFT JOIN orders o ON d.order_id = o.order_id
        LEFT JOIN obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set  IN (#{hypertensition_medication_id}, #{asthma_id},#{diabetes_id}, #{epilepsy_id})))
        AND quantity > 0
        AND obs.voided = 0
        AND o.voided = 0
        AND obs.person_id = #{patient.id}
    ORDER BY obs.obs_datetime ASC
    LIMIT 1
    "
    start_date.to_date rescue nil

  end

 def rebuild_ccc_program_states(patient_program_id, patient_id)

		#raise patient_program_id.to_yaml
    current_patient_program = PatientProgram.find(patient_program_id)
    # gather initial data for the particular program required data
    program_id = current_patient_program.program_id
    location_id = current_patient_program.location_id
    initial_date = Date.today
    program_states_to_void = [83,84,85,86,157,158] #transferred out, dead, treatment stopped, on arvs

    # find patient
    patient = Patient.find(patient_id)

    # delete the program associated states
    current_patient_program.patient_states.each do |state|
      state.void if program_states_to_void.include? state.state
    end

    if current_patient_program.patient_states.blank?
      initial_patient_state = current_patient_program.patient_states.build(
        :state => 157, #TODO find a better way of getting the this state rather than hard coding
        :start_date => initial_date,
        :creator => current_patient_program.creator)
      initial_patient_state.save
    end

    # create on ART state if the patient has any art dispensation
    #TODO check if the patient has any art dispensation, and get the date of the earliest start date

    date_of_first_dispensation = first_dispensation(patient) rescue nil

    if ! date_of_first_dispensation.nil?
      on_treatment_state = current_patient_program.patient_states.build(
        :state => 83, #TODO find a better way of getting the this state rather than hard coding
        :start_date => date_of_first_dispensation,
        :creator => current_patient_program.creator) #TODO use the date obtained from the check above
      on_treatment_state.save

      # update the start date of the pre ART state from
      if ! initial_patient_state.nil?
        initial_patient_state[:start_date] = date_of_first_dispensation
        initial_patient_state[:end_date] = date_of_first_dispensation
        initial_patient_state.save
      end
      patient_on_treatment = true
    end
    # set patient deathdate and dead pointer to nil

    patient.person[:death_date] = "NULL"
    patient.person[:dead] = 0
    patient.person.save

    exit_from_care_encounter_type = EncounterType.find_by_name("UPDATE OUTCOME").id
    exit_from_care_encounter = Encounter.find_by_sql("
      SELECT * FROM encounter e INNER JOIN program_encounter_details p ON e.encounter_id = p.encounter_id
     WHERE encounter_type = #{ exit_from_care_encounter_type} AND patient_id =#{patient.patient_id}
     AND e.voided = 0")

		#raise exit_from_care_encounter.to_yaml
    exit_from_care_encounter.each do |encounter| #loop through the encounters of exit from care encounters
      exit_from_care_type = ''
      exit_from_care_date = ''

      encounter.observations.each do |obs| #loop through the observations to get the individual values of the exit from care observation
          exit_from_care_type = ConceptName.find_by_concept_name_id(obs.value_coded_name_id).name
          exit_from_care_date = obs.value_datetime
      end #end of obs loop



      if exit_from_care_type.to_s.upcase == "PATIENT DIED" #add patient_died state
        #show patient as died in patient_table
        patient.person[:death_date] = exit_from_care_date
        patient.person[:dead] = 1
        patient.person.save

        dead_patient_state = current_patient_program.patient_states.build(
          :state => 85, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        dead_patient_state.save

      elsif exit_from_care_type.to_s.upcase == "PATIENT TRANSFERRED OUT"

        transfer_out_patient_state = current_patient_program.patient_states.build(
          :state => 84, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        transfer_out_patient_state.save

      elsif exit_from_care_type.to_s.upcase == "TREATMENT STOPPED"

        stopped_patient_state = current_patient_program.patient_states.build(
          :state => 158, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        stopped_patient_state.save

     elsif exit_from_care_type.to_s.upcase == "DISCHARGED"

        stopped_patient_state = current_patient_program.patient_states.build(
          :state => 86, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        stopped_patient_state.save

       elsif exit_from_care_type.to_s.upcase == "ON TREATMENT"

        stopped_patient_state = current_patient_program.patient_states.build(
          :state => 83, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        stopped_patient_state.save
      end

      #update the the on_arvs state, append the exit from care date if the patient is on arvs
			if ! on_treatment_state.nil?
				on_treatment_state[:end_date] = exit_from_care_date.to_date
				on_treatment_state.save
			end

      #update the end date for the patient program
      current_patient_program.date_completed = exit_from_care_date
      current_patient_program.save

      #check for dispensation after the exit from care state
      next_dispensation_date = dispensation_date_after(patient, exit_from_care_date.to_date)

      if ! next_dispensation_date.nil?
        #reset the end date of the program
        current_patient_program.date_completed = 'NULL'
        current_patient_program.save

        #create On ARVs state

        on_treatment_state = current_patient_program.patient_states.build(
          :state => 83, #TODO find a better way of getting the this state rather than hard coding
          :start_date => next_dispensation_date,
          :creator => current_patient_program.creator) #TODO use the date obtained from the check above
        on_treatment_state.save

      end
    end #end of encounters loop

  end


 def rebuild_program_states(patient_program_id, patient_id)

		#raise patient_program_id.to_yaml
    current_patient_program = PatientProgram.find(patient_program_id)
    # gather initial data for the particular program required data
    program_id = current_patient_program.program_id
    location_id = current_patient_program.location_id
    initial_date = Date.today
    program_states_to_void = [2,3,6,7] #transferred out, dead, treatment stopped, on arvs
    pre_art_state = 1

    # find patient
    patient = Patient.find(patient_id)

    # delete the program associated states
    current_patient_program.patient_states.each do |state|
      state.void if program_states_to_void.include? state.state
    end

    pre_art_state_exists = true if current_patient_program.patient_states.map(&:state).include? pre_art_state
    # create pre ART state for the program
    if ! pre_art_state_exists == true
      initial_patient_state = current_patient_program.patient_states.build(
        :state => 1, #TODO find a better way of getting the this state rather than hard coding
        :start_date => initial_date,
        :creator => current_patient_program.creator)
      initial_patient_state.save
    else
      #ensure that initial state is known, so that we can assign
      #end date of the beginning of the on arv state
      current_patient_program.patient_states.each do |state|
        initial_patient_state = state if state.state == pre_art_state
      end
    end

    # create on ART state if the patient has any art dispensation
    #TODO check if the patient has any art dispensation, and get the date of the earliest start date

    date_of_first_dispensation = PatientService.date_of_first_dispensation(patient) rescue nil

    if ! date_of_first_dispensation.nil?
      on_arv_state = current_patient_program.patient_states.build(
        :state => 7, #TODO find a better way of getting the this state rather than hard coding
        :start_date => date_of_first_dispensation,
        :creator => current_patient_program.creator) #TODO use the date obtained from the check above
      on_arv_state.save

      # update the start date of the pre ART state from
      if ! initial_patient_state.nil?
        initial_patient_state[:start_date] = date_of_first_dispensation
        initial_patient_state[:end_date] = date_of_first_dispensation
        initial_patient_state.save
      end
      patient_on_arvs = true
    end
    # set patient deathdate and dead pointer to nil

    patient.person[:death_date] = "NULL"
    patient.person[:dead] = 0
    patient.person.save

    exit_from_care_encounter_type = EncounterType.find_by_name("EXIT FROM HIV CARE").id
    exit_from_care_encounter = Encounter.find(:all,
      :conditions => ["encounter_type = ? AND patient_id = ? AND voided = 0",
        exit_from_care_encounter_type, patient.patient_id]
    )

    reason_for_exiting_care = ConceptName.find_by_name("REASON FOR EXITING CARE").concept_id
    date_of_exiting_care = ConceptName.find_by_name("DATE OF EXITING CARE").concept_id

		#raise exit_from_care_encounter.to_yaml
    exit_from_care_encounter.each do |encounter| #loop through the encounters of exit from care encounters
      exit_from_care_type = ''
      exit_from_care_date = ''

      encounter.observations.each do |obs| #loop through the observations to get the individual values of the exit from care observation
        if obs.concept_id == reason_for_exiting_care
          exit_from_care_type = ConceptName.find_by_concept_name_id(obs.value_coded_name_id).name
        elsif obs.concept_id == date_of_exiting_care
          exit_from_care_date = obs.value_datetime
        end
      end #end of obs loop



      if exit_from_care_type.to_s.upcase == "PATIENT DIED" #add patient_died state
        #show patient as died in patient_table
        patient.person[:death_date] = exit_from_care_date
        patient.person[:dead] = 1
        patient.person.save

        dead_patient_state = current_patient_program.patient_states.build(
          :state => 3, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        dead_patient_state.save

      elsif exit_from_care_type.to_s.upcase == "PATIENT TRANSFERRED OUT"

        transfer_out_patient_state = current_patient_program.patient_states.build(
          :state => 2, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        transfer_out_patient_state.save

      elsif exit_from_care_type.to_s.upcase == "TREATMENT STOPPED"

        stopped_patient_state = current_patient_program.patient_states.build(
          :state => 6, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => current_patient_program.creator)
        stopped_patient_state.save
      end

      #update the the on_arvs state, append the exit from care date if the patient is on arvs
			if ! on_arv_state.nil?
				on_arv_state[:end_date] = exit_from_care_date.to_date
				on_arv_state.save
			end

      #update the end date for the patient program
      current_patient_program.date_completed = exit_from_care_date
      current_patient_program.save

      #check for dispensation after the exit from care state
      next_dispensation_date = PatientService.date_dispensation_date_after(patient, exit_from_care_date.to_date)

      if ! next_dispensation_date.nil?
        #reset the end date of the program
        current_patient_program.date_completed = 'NULL'
        current_patient_program.save

        #create On ARVs state

        on_arv_state = current_patient_program.patient_states.build(
          :state => 7, #TODO find a better way of getting the this state rather than hard coding
          :start_date => next_dispensation_date,
          :creator => current_patient_program.creator) #TODO use the date obtained from the check above
        on_arv_state.save

      end
    end #end of encounters loop

  end


init