require "csv"
HIV_PROGRAM = Program.find_by_name('HIV Program')
UnknownLocation = Location.find_by_name('Unknown')
Location.current_location = Location.find_by_name('Unknown')

def start
  User.current = User.find(1)

  arv_numbers = []
  csv_url =  RAILS_ROOT + "/doc/THYOLOTRANSFEREDOUT.csv"
  CSV.foreach("#{csv_url}") do |row|
    arv_number = row[2].to_i rescue 0
    next if arv_number < 1
    arv_numbers << arv_number
  end

  #find a patient using the ARV number and update the outcome
  (arv_numbers || []).each do |arv_number|
    valid_arv_num = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
    patient = PatientIdentifier.find_by_identifier(valid_arv_num).patient rescue nil
    next if patient.blank?
    outcome_date = get_latest_encounter_date(patient)
    next if outcome_date.blank?
    update_program(patient, outcome_date)
    puts "Patient transferred out - ARV number:#{valid_arv_num}"
  end
end

def update_outcome(patient, outcome_date)
  patient_program = PatientProgram.find(:first,:conditions =>["patient_id = ? AND
    program_id = ? AND date_completed IS NULL", patient.id, HIV_PROGRAM.id])

  unless patient_program.blank?
    patient_program.date_completed = outcome_date
    patient_program.save
  end

end

def get_latest_encounter_date(patient)
  Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_datetime = (
    SELECT MAX(e.encounter_datetime) FROM encounter e WHERE e.patient_id = #{patient.id})",
                                       patient.id]).encounter_datetime rescue nil
end

start
