require "csv"
HIV_PROGRAM = Program.find_by_name('HIV Program')
UnknownLocation = Location.find_by_name('Unknown')
Location.current_location = Location.find_by_name('Unknown')

def start
  User.current = User.find(1)

  arv_numbers = []

  csv_url =  RAILS_ROOT + "/doc/Thyolo_Died_List.csv"
  CSV.foreach("#{csv_url}") do |row|
    arv_number = row[2].to_s.split("/")[0].to_i rescue 0
    next if arv_number < 1
    arv_numbers << arv_number
  end
  count = 0
  #find a patient using the ARV number and update the outcome
  (arv_numbers || []).each do |arv_number|
    valid_arv_num = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
    patient = PatientIdentifier.find_by_identifier(valid_arv_num).patient rescue nil

    next if patient.blank? || patient.person.dead == 1
    outcome_date = get_latest_encounter_date(patient)
    next if outcome_date.blank?
    update_outcome(patient, outcome_date)
    puts "Patient Died - ARV number:#{valid_arv_num}"

  end
  puts count
end

def update_outcome(patient, outcome_date)
  patient_program = PatientProgram.find(:first,:conditions =>["patient_id = ? AND
    program_id = ? AND date_completed IS NULL", patient.id, HIV_PROGRAM.id])

  if patient_program.blank?
    patient_program = PatientProgram.create(:patient_id => patient.id,
                                            :program_id => HIV_PROGRAM.id, :date_enrolled => outcome_date,:creator => 1)
  end

  current_active_state = patient_program.patient_states.last rescue []
  unless current_active_state.blank?
    current_active_state.end_date = outcome_date.to_date
    current_active_state.save
  end
  current_active_state = PatientState.create(:patient_program_id => patient_program.id,
                                             :state => 3, :start_date => outcome_date.to_date)

  create_exit_from_care_encounter(patient, outcome_date, current_active_state)
  update_person(patient, outcome_date)
  patient_program.date_completed = outcome_date
  patient_program.save
end

def get_latest_encounter_date(patient)
  Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_datetime = (
    SELECT MAX(e.encounter_datetime) FROM encounter e WHERE e.patient_id = #{patient.id})",
                                       patient.id]).encounter_datetime rescue nil
end

def create_exit_from_care_encounter(patient, outcome_date, current_active_state)
=begin
  states_to_create_encounter_for = []
  concept_set("EXIT FROM CARE").each{|concept| states_to_create_encounter_for << concept.uniq.to_s}

  current_state = given_params[:current_state]
=end

  new_encounter = {"encounter_datetime" => outcome_date ,
                   "encounter_type"=> EncounterType.find_by_name("EXIT FROM HIV CARE").id,
                   "patient_id" => patient.id,
                   "provider_id" => 1 }

  encounter = Encounter.new(new_encounter)
  encounter.encounter_datetime = outcome_date
  encounter.save

  reason_obs = {}
  reason_obs[:concept_name] = 'REASON FOR EXITING CARE'
  reason_obs[:encounter_id] = encounter.id
  reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
  reason_obs[:person_id] ||= encounter.patient_id
  reason_obs['value_coded_or_text'] = 'Patient died'
  Observation.create(reason_obs)

  date_obs = {}
  date_obs[:concept_name] = 'DATE OF EXITING CARE'
  date_obs[:encounter_id] = encounter.id
  date_obs[:obs_datetime] = outcome_date
  date_obs[:person_id] ||= patient.id
  date_obs['value_datetime'] = outcome_date
  Observation.create(date_obs)

end

def update_person(patient, outcome_date)
  person = patient.person
  person.dead = 1
  person.death_date = outcome_date
  person.save
end

start
