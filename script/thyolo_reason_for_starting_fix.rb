# Script written to fix problem with thyolo data where patients are put as having unknown reason for starting whilst
# there was a valid reason

require 'mysql'
$cd4_count_less_than_250 = Concept.find_by_name("cd4 count <= 250")
$cd4_count_less_than_350 = Concept.find_by_name("cd4 count <= 350")
$user = User.first

def start

  enc_type = EncounterType.find_by_name("HIV STAGING").id

  patients_with_unknown_reasons = []


  #Get all patients on ar
  art_patient = Patient.find_by_sql("select distinct patient_id from earliest_start_date")

  puts " Number of ART Patients : #{art_patient.count}"

  #Filtering patients with unknown start reasons
  (art_patient || []).each do |patient|
    reason = PatientService.reason_for_art_eligibility(patient)
    patients_with_unknown_reasons << patient unless reason != "Unknown"
  end

  puts " Number of ART Patients With Unknown Start Reason : #{patients_with_unknown_reasons.count}"

  (patients_with_unknown_reasons || []).each do |patient|

    #For each patient with unknow start reason check if cd4 count could be the reason. If correct save
    last_hiv_staging_encounter = Encounter.find(:last, :conditions => ["patient_id = ? 
      AND encounter_type = ? AND voided = 0 AND encounter_datetime = (SELECT MAX(e.encounter_datetime)
      FROM encounter e WHERE e.encounter_type = #{enc_type} 
      AND e.patient_id=#{patient.id} AND e.voided = 0)", patient.id, enc_type ])

    next if last_hiv_staging_encounter.blank?

    encounter_observations = last_hiv_staging_encounter.observations.collect{|x| [x.concept.fullname, x.value_numeric, x.obs_datetime]}

    #call method to check viability of cd4 as start reason
    reason = get_reason_for_eligibility(encounter_observations)

    #Save if reason is not unknown

    unless reason == "Unknown"
      puts "Patient ID #{patient.id} has start reason found : #{reason.fullname rescue reason.shortname}"
      old_reason = last_hiv_staging_encounter.observations.question("Reason for art eligibility").first
      new_reason = Observation.create({ :person_id => patient.id, :concept_id => old_reason.concept_id,
                                        :encounter_id => old_reason.encounter_id, :obs_datetime => old_reason.obs_datetime,
                                        :value_coded => reason.id, :creator => $user.id,
                                        :value_coded_name_id => reason.concept_names.typed('SHORT').first.concept_name_id })
      old_reason.voided = 1
      old_reason.voided_by = $user
      old_reason.date_voided = Date.today
      old_reason.void_reason = "Data cleaning script found viable start reason"
      old_reason.save
    end
  end

end

def get_reason_for_eligibility(observations)

  cd4_count = ""
  obs_date = ""


  (observations || []).each do |name,number, date|

     if name.upcase == "CD4 COUNT"
          cd4_count = number
          obs_date = date
      end

  end

  if !cd4_count.blank?
    if cd4_count.to_i <= 250 and (obs_date.to_date < '2011-07-01'.to_date)
      return $cd4_count_less_than_250
    elsif cd4_count.to_i <= 350 and (obs_date.to_date >= '2011-07-01'.to_date)
      return $cd4_count_less_than_350
    end
  end

  return "Unknown"
end


start
