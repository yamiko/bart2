class ValidationRule < ActiveRecord::Base
  def self.data_consistency_checks(date = Date.today)

  end

  def self.create_update_validation_result(rule, date, result)

  end

  def self.validate_presence_of_start_reason
    #This function checks for patients who do not have a reason for starting ART

    start_reason_concept = Concept.find_by_name("Reason for art eligibility").id

    patient_ids = PatientProgram.find_by_sql("SELECT patient_id FROM earliest_start_date where patient_id NOT IN
                (SELECT distinct person_id from obs where concept_id = #{start_reason_concept} and voided = 0)")

    return patient_ids

  end

end
