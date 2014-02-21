class ValidationRule < ActiveRecord::Base
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

end
