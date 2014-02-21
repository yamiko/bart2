class ValidationRule < ActiveRecord::Base
  @dispensed_id = ConceptName.find_by_name('PILLS DISPENSED').concept_id

  def self.data_consistency_checks(date = Date.today)

  end

  def self.create_update_validation_result(rule, date, result)

  end

  def self.validate_presence_of_start_reason
    #This function checks for patients who do not have a reason for starting ART

    start_reason_concept = Concept.find_by_name("Reason for art eligibility").id

    patient_ids = PatientProgram.find_by_sql("SELECT patient_id FROM earliest_start_date where patient_id NOT IN
                (SELECT distinct person_id from obs where concept_id = #{start_reason_concept} and voided = 0)")

    if !patient_ids.blank?
      violated_rule_id = ValidationRule.find_by_desc("Patients without reason for starting ARVs").id
      ValidationResult.create(:rule_id => violated_rule_id, :failures => patient_ids.length, :date_checked => Date.today)
    end

  end

  def self.dispensation_without_prescription(end_date = Date.today)
    unprescribed = Observation.find_by_sql("
                                  SELECT DISTINCT(person_id)  FROM obs
                                  WHERE (order_id <=> NULL)
                                  AND concept_id = #{@dispensed_id}
                                  AND voided = 0;").length
    return unprescribed
  end

  def self.prescrition_without_dispensation(end_date = Date.today)
    undispensed = Order.find_by_sql("
                                    SELECT DISTINCT(patient_id) FROM orders
                                    WHERE NOT EXISTS (SELECT order_id FROM obs WHERE order_id = orders.order_id
                                    AND concept_id = #{@dispensed_id} and  voided = 0)
                                    AND orders.voided = 0")
    return undispensed.length
  end

  def self.dispensation_without_appointment(end_date = Date.today)
    no_appointment = Observation.find_by_sql("
                                    SELECT DISTINCT(person_id) FROM obs
                                    WHERE concept_id = #{@dispensed_id}
                                    AND voided = 0
                                    AND person_id NOT IN
                                    (SELECT person_id FROM obs o
                                    INNER JOIN encounter e ON o.person_id = e.patient_id
                                    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                                    WHERE et.name = 'Appointment'
                                    AND o.obs_datetime = obs_datetime
                                    AND o.person_id = person_id
                                    AND o.voided = 0)").length
    return no_appointment
  end 
end
