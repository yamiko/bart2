class ValidationRule < ActiveRecord::Base

  def self.patients_without_outcomes(visit_date)
    visit_date = visit_date.to_date rescue Date.today
    connection = ActiveRecord::Base.connection
    patient_ids = []
    without_outcome_ids = connection.select_all("
        SELECT e.patient_id as patient_id FROM encounter e INNER JOIN patient p
        ON e.patient_id=p.patient_id INNER JOIN patient_program pp ON p.patient_id=pp.patient_id
        LEFT JOIN patient_state ps ON pp.patient_program_id=ps.patient_program_id
        WHERE ps.patient_state_id IS NULL AND (e.voided=0 AND pp.voided=0 OR ps.voided=0)
        AND DATE(e.encounter_datetime) <= \'#{visit_date}\'
        GROUP BY patient_id

      ")
    
    without_outcome_ids.each do |pid|
      patient_ids << pid["patient_id"]
    end
    return patient_ids
  end

  def self.pills_remaining_over_dispensed
    connection = ActiveRecord::Base.connection
    data = {}
    patient_ids = []
    art_adherence_enc = EncounterType.find_by_name('ART ADHERENCE').id
    dispensing_enc = EncounterType.find_by_name('DISPENSING').id
    amount_dispensed_concept = Concept.find_by_name('AMOUNT DISPENSED').id
    amount_brought_to_clinic_concept = Concept.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').id
    adhere_dispensing_encs = connection.select_all("
        SELECT * FROM encounter e WHERE encounter_type IN (#{art_adherence_enc}, #{dispensing_enc})
        AND e.voided=0 ORDER BY DATE(e.encounter_datetime) DESC LIMIT 4000

      ")
    adhere_dispensing_encs.each do |enc|

      enc_date = enc["encounter_datetime"].to_date
      enc_name = EncounterType.find(enc["encounter_type"]).name.upcase
      encounter = Encounter.find(enc["encounter_id"])
      patient_id = enc["patient_id"]
      if (data[enc_date].blank?)
        data[enc_date] = {}
      end
      if (data[enc_date][patient_id].blank?)
        data[enc_date][patient_id] = {:amount_dispensed => nil, :amount_brought_to_clinic => nil}
      end
      if (enc_name == 'DISPENSING')
        amount_dispensed = encounter.observations.find(:last, :conditions => ["concept_id =?", amount_dispensed_concept]).value_numeric rescue nil
      end
      
      if (enc_name == 'ART ADHERENCE')
        amount_brought_to_clinic = encounter.observations.find(:last, :conditions => ["concept_id =?", amount_brought_to_clinic_concept]).value_numeric rescue nil
      end
      
      unless (amount_dispensed.blank?)
        data[enc_date][patient_id][:amount_dispensed] = amount_dispensed
      end
      
      unless amount_brought_to_clinic.blank?
        data[enc_date][patient_id][:amount_brought_to_clinic] = amount_brought_to_clinic
      end
    end
    return data
  end
  
end
