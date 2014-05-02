require 'csv'

Location.current_location = Location.find(1)
User.current = User.find(1)


HIV_CLINIC_REGISTRATION_ENC_TYPE = EncounterType.find_by_name('HIV CLINIC REGISTRATION')
YES = ConceptName.find_by_name('YES').concept
PREGNANT_WHEN_STARTING = ConceptName.find_by_name('Pregnant at initiation?').concept

def start

  patients = []

  csv_url =  RAILS_ROOT + "/doc/pregnant_at_start.csv"  #where the CSV file containing the ARV numbers will be
  CSV.foreach("#{csv_url}") do |row|
    arv_number = row[0].upcase rescue nil
    next if arv_number.blank?
    patient = PatientIdentifier.find_by_identifier(arv_number).patient rescue nil
    next if patient.blank?
    patients << patient 
  end

  #find a patient using the ARV number and update the outcome
  (patients || []).each do |patient|
    registration = Encounter.find(:fisrt,:conditions =>["encounter_type = ? AND patient_id = ?",
      HIV_CLINIC_REGISTRATION_ENC_TYPE.id,patient.id])
    if registration.blank?
      registration = create_registration_encounter(patient.id)
    end
    next if registration.blank?
    create_obs(registration)
    puts "Patient given a new obs:#{arv_number}"
  end
end

def create_obs(encounter)
  obs_datetime = get_earliest_start_date(encounter.patient_id)
  return if obs_datetime.blank?
  Observation.create(:encounter_id => encounter.id,
    :person_id => encounter.patient_id,
    :obs_datetime => obs_datetime.to_date.strftime('%Y-%m-%d 00:00:01'),
    :concept_id => PREGNANT_WHEN_STARTING.id,
    :value_coded => YES.id)
end

def create_registration_encounter(patient_id)
  encounter_datetime = get_earliest_start_date(patient_id)
  return if encounter_datetime.blank?

  Encounter.create(:patient_id => patient_id,
    :encounter_type => HIV_CLINIC_REGISTRATION_ENC_TYPE.id,
    :encounter_datetime => encounter_datetime.to_date.strftime('%Y-%m-%d 00:00:01'))
end

def get_earliest_start_date(patient_id)
  Encounter.find_by_sql("SELECT earliest_start_date FROM earliest_start_date
    WHERE patient_id = #{patient_id}").first.earliest_start_date.to_date.strftime('%Y-%m-%d 00:00:01') rescue nil
end

start
