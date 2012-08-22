class ProgramsController < GenericProgramsController
  
    
  def create_exit_from_care_encounter(given_params)
    states_to_create_encounter_for = []
    concept_set("EXIT FROM CARE").each{|concept| states_to_create_encounter_for << concept.uniq.to_s}
 
    current_state = ProgramWorkflowState.find(given_params[:current_state]).concept.fullname

    if states_to_create_encounter_for.include? current_state
      new_encounter = {"encounter_datetime"=> params[:encounter][:encounter_datetime],
                       "encounter_type_name"=>"EXIT FROM CARE",
                       "patient_id"=> params[:patient_id],
                       "provider_id"=>params[:encounter][:provider_id]}
      
      encounter = Encounter.new(new_encounter)
      encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      encounter.save

      reason_obs = {} 
      reason_obs[:concept_name] = 'REASON FOR EXITING CARE'
      reason_obs[:encounter_id] = encounter.id
      reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      reason_obs[:person_id] ||= encounter.patient_id
      reason_obs['value_coded_or_text'] = current_state
      Observation.create(reason_obs)
      
      date_obs = {} 
      date_obs[:concept_name] = 'DATE OF EXITING CARE'
      date_obs[:encounter_id] = encounter.id
      date_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      date_obs[:person_id] ||= encounter.patient_id
      date_obs['value_datetime'] = given_params[:current_date]
      Observation.create(date_obs)
      
      rebuild_program_states(given_params[:patient_program_id], given_params[:encounter][:patient_id])
    end
  end
  def rebuild_program_states(patient_program_id, patient_id)
    
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
 
    pre_art_state_exists == true if current_patient_program.patient_states.map(&:state).include? pre_art_state
    # create pre ART state for the program
    if ! pre_art_state_exists == true
        initial_patient_state = current_patient_program.patient_states.build(
          :state => 1, #TODO find a better way of getting the this state rather than hard coding
          :start_date => initial_date,
          :creator => User.current.user_id)
        initial_patient_state.save 
    end
    
    # create on ART state if the patient has any art dispensation
    #TODO check if the patient has any art dispensation, and get the date of the earliest start date
    
    date_of_first_dispensation = PatientService.date_of_first_dispensation(patient)
    if ! date_of_first_dispensation.nil?

      on_arv_patient_state = current_patient_program.patient_states.build(
        :state => 7, #TODO find a better way of getting the this state rather than hard coding
        :start_date => date_of_first_dispensation,
        :creator => User.current.user_id) #TODO use the date obtained from the check above
      on_arv_patient_state.save
      
      # update the start date of the pre ART state from
      if ! initial_patient_state.nil?
        initial_patient_state[:start_date] = date_of_first_dispensation
        initial_patient_state.save
      end
      patient_on_arvs == true
    end
    # set patient deathdate and dead pointer to nil
       
    patient.person[:death_date] = null
    patient.person[:dead] = 0
    patient.person.save
    
    exit_from_care_encounter_type = EncounterType.find_by_name("Exit from care").id
    exit_from_care_encounter = Encounter.find(:all, 
                                              :conditions => ["encounter_type = ? AND patient_id = ?", 
                                                exit_from_care_encounter_type, patient.patient_id]
                                              )
    
    reason_for_exiting_care = ConceptName.find_by_name("REASON FOR EXITING CARE").concept_id
    date_of_exiting_care = ConceptName.find_by_name("DATE OF EXITING CARE").concept_id
    

    exit_from_care_encounter.each do |encounter|  #loop through the encounters of exit from care encounters
      exit_from_care_type = ''
      exit_from_care_date = ''
      
      encounter.observations.each do |obs|  #loop through the observations to get the individual values of the exit from care observation
        if obs.concept_id == reason_for_exit
          exit_from_care_type = ConceptName.find_by_concept_name_id(obs.value_coded_name_id).name
        elsif obs.concept_id == date_of_exiting_care
          exit_crom_care_date = obs.value_datetime
        end
      end #end of obs loop
      
      if exit_from_care_type.to_s.upcase == "PATIENT DIED"    #add patient_died state
        #show patient as died in patient_table
        patient.person[:death_date] = exit_from_care_date
        patient.person[:dead] = 1
        patient.person.save

        dead_patient_state = current_patient_program.patient_states.build(
          :state => 3, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => User.current.user_id)
        dead_patient_state.save 
                    
      elsif exit_from_care_type.to_s.upcase == "PATIENT TRANSFERRED OUT"

        transfer_out_patient_state = current_patient_program.patient_states.build(
          :state => 2, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => User.current.user_id)
        transfer_out_patient_state.save 
        
      elsif exit_from_care_type.to_s.upcase == "TREATMENT STOPPED"

        stopped_patient_state = current_patient_program.patient_states.build(
          :state => 6, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => User.current.user_id)
        stopped_patient_state.save 
      
      end 
      
      #update the end date for the patient program    
      current_patient_program.date_completed = exit_from_care_date
      current_patient_program.save
      
      #check for dispensation after the exit from care state
      next_dispensation_date = PatientService.date_dispensation_date_after(patient, exit_from_care_date)
      
      if ! next_dispensation_date.nil?
        #reset the end date of the program
        current_patient_program.date_completed = null
        current_patient_program.save
        
        #create On ARVs state
        
        on_arv_state = current_patient_program.patient_states.build(
          :state => 7, #TODO find a better way of getting the this state rather than hard coding
          :start_date => next_dispensation_date,
          :creator => User.current.user_id) #TODO use the date obtained from the check above
        on_arv_state.save
     
      end
    end #end of encounters loop
    
  end 

end
