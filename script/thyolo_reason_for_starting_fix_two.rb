
REASON_FOR_STARTING = ConceptName.find_by_name('Reason for ART eligibility')
HIV_STAGING_ENC_TYPE = EncounterType.find_by_name('HIV Staging')


CD4Count250 = ConceptName.find_by_name('CD4 count less than or equal to 250')
CD4Count350 = ConceptName.find_by_name('CD4 count less than or equal to 350')


WHO4_ADULT = ConceptName.find_by_name('WHO stage IV adult')
WHO3_ADULT = ConceptName.find_by_name('WHO stage III adult')
WHO4_PEADS = ConceptName.find_by_name('WHO stage IV peds')
WHO3_PEADS = ConceptName.find_by_name('WHO stage III peds')

Breastfeeding = ConceptName.find_by_name('Breastfeeding')
PatientPregnant = ConceptName.find_by_name('Patient pregnant')
DNA_PCR = ConceptName.find_by_name('DNA PCR')
Unknown = ConceptName.find_by_name('Unknown')


def start
  User.current = User.find(1)

  arv_numbers = {}
  csv_url =  RAILS_ROOT + "/doc/UnkownstartReasonsThyolo.csv"
  FasterCSV.foreach("#{csv_url}", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
    arv_number = row[0].upcase rescue nil
    start_reason = row[1]
    next if arv_number.blank?
    next if start_reason.blank?
    arv_numbers[arv_number] = start_reason
  end

  #find a patient using the ARV number and update the outcome
  (arv_numbers || {}).each do |arv_number,start_reason|
    patient = PatientIdentifier.find_by_identifier(arv_number).patient rescue nil
    next if patient.blank?
    reason_for_starting_enc = get_latest_hiv_encounter(patient)
    next if reason_for_starting_enc.blank?
    update_reason_for_starting(patient, reason_for_starting_enc, start_reason)
    puts "Patient given a reason for starting - ARV number:#{arv_number}"
  end
end

def update_reason_for_starting(patient, reason_for_starting_enc, start_reason)
  reason_for_starting = Observation.find(:first,:conditions =>["person_id = ? AND
    concept_id = ? AND value_coded IS NOT NULL", patient.id, REASON_FOR_STARTING.id])

  if reason_for_starting.blank?
    Observation.create(:person_id => patient.id,
      :concept_id => REASON_FOR_STARTING.id,
      :obs_datetime => reason_for_starting_enc.encounter_datetime,
      :encounter_id => reason_for_starting_enc.id,
      :value_coded => get_start_reason(patient, start_reason))
  else
    reason_for_starting.value_coded = get_start_reason(patient, reason_for_starting_enc.encounter_datetime, start_reason)
    reason_for_starting.save
  end

end

def get_latest_hiv_encounter(patient)
  Encounter.find(:fisrt,:conditions =>["patient_id = ? AND encounter_type = ? 
    AND encounter_datetime = (SELECT MAX(e.encounter_datetime) FROM encounter e 
    WHERE e.patient_id = #{patient.id})",patient.id,
    HIV_STAGING_ENC_TYPE.id]) #.encounter_datetime rescue nil
end

def get_start_reason(patient, start_date, reason)
  if reason.match(/CD4/i)
    if start_date.to_date <= '2011-07-01'.to_date
      return CD4Count250.id
    else
      return CD4Count350.id
    end
  elsif reason.match(/Stage 3/i)
    if PatientService.age(patient.person, start_date.to_date) <= 14
      return WHO3_PEADS.id
    else
      return WHO3_ADULT.id
    end
  elsif reason.match(/Stage 4/i)
    if PatientService.age(patient.person, start_date.to_date) <= 14
      return WHO4_PEADS.id
    else
      return WHO4_ADULT.id
    end
  elsif reason.match(/Pregnant/i)
    return Pregnant.id
  elsif reason.match(/PCR/i)
    return DNA_PCR.id
  elsif reason.match(/Stage3/i)
    if PatientService.age(patient.person, start_date.to_date) <= 14
      return WHO3_PEADS.id
    else
      return WHO3_ADULT.id
    end
  elsif reason.match(/Breastfeeding/i)
    return Breastfeeding.id
  elsif reason.match(/Preg/i)
    return Pregnant.id
  else
    Unknown.id
  end
end

start
