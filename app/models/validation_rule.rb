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

    return patient_ids

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
  def self.validate_presence_of_vitals_without_weight(end_date)
    # Developer   : Precious Bondwe
    # Date        : 21/02/2014
    # Purpose     : Return Patient IDs for patients having Vitals encounters without weight 
    # Amendments  :

    weight_concept = ConceptName.find_by_name('weight').concept_id
    encounter_type = EncounterType.find_by_name('vitals').id
    
    patient_ids = ValidationRule.find_by_sql("SELECT DISTINCT e.patient_id 
                          FROM encounter e 
                              LEFT JOIN obs o ON e.encounter_id = o.encounter_id AND o.concept_id = #{weight_concept} AND o.voided = 0
                               WHERE o.concept_id IS NULL AND e.voided = 0 AND e.encounter_type = #{encounter_type} 
                               AND e.encounter_datetime <= '#{end_date}'").map(&:patient_id) 
    
    return patient_ids
  end

  def self.death_date_less_than_last_encounter_date_and_less_than_date_of_birth(end_date = Date.today)
    patient_ids =  ValidationRule.find_by_sql("SELECT DISTICT(esd.patient_id)
																FROM earliest_start_date esd
																INNER JOIN person p 
																ON p.person_id = esd.patient_id
																WHERE p.birthdate IS NOT NULL 
																AND esd.death_date IS NOT NULL 
																AND esd.death_date < (SELECT MAX(encounter_datetime)
                       																 FROM encounter e 
                       																 WHERE e.patient_id = esd.patient_id 
																											 AND e.voided = 0) 
                                AND (SELECT MAX(encounter_datetime)
                       							 FROM encounter e 
                       							 WHERE e.patient_id = esd.patient_id 
																		 AND e.voided = 0) < p.birthdate;").map(&:patient_id)
    return patient_ids
    
  end

  def self.validate_newly_registered_is_sum_of_initiated_reinited_and_transferred_in(start_date = @start_date, end_date = @end_date)
    total_registered = []
    total_initiated = []
    total_reinitiated = []
    total_transferred_in = []
 
	  total_registered =  ValidationRule.find_by_sql("SELECT * FROM earliest_start_date 
	    WHERE earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'").map(&:patient_id)
    
    yes_concept = ConceptName.find_by_name('YES').concept_id
		no_concept = ConceptName.find_by_name('NO').concept_id
    date_art_last_taken_concept = ConceptName.find_by_name('DATE ART LAST TAKEN').concept_id

    taken_arvs_concept = ConceptName.find_by_name('HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS').concept_id 
    
    total_reinitiated =  ValidationRule.find_by_sql("SELECT esd.*
																										FROM earliest_start_date esd
																										LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
																										INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
																										LEFT JOIN obs o ON o.encounter_id = e.encounter_id AND
																																			 o.concept_id IN (#{date_art_last_taken_concept},#{taken_arvs_concept})
																										WHERE  ((o.concept_id = #{date_art_last_taken_concept} AND
																														 (DATEDIFF(o.obs_datetime,o.value_datetime)) > 60) OR
																													 (o.concept_id = #{taken_arvs_concept} AND
																														(o.value_coded = #{no_concept})
																														))
																													AND
																													esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
																										GROUP BY esd.patient_id").map(&:patient_id)
				
   
    total_initiated =  ValidationRule.find_by_sql("SELECT esd.*
																									FROM earliest_start_date esd
																									LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
																									LEFT JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
																									WHERE esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND
																													(ero.obs_id IS NULL)
																									GROUP BY esd.patient_id").map(&:patient_id)

    total_initiated -= total_reinitiated
    
    total_transferred_in = total_registered - reinitiated - initiated
    
    total_sum = total_transferred_in + reinitiated + initiated

    unless total_registered == total_sum
    		return false
    else
    		return true
    end
  
  end

  end 
  
  def self.encounters_without_obs_or_orders(end_date = Date.today)
		
		start_date = Encounter.find_by_sql("SELECT MIN(encounter_datetime) start_date FROM encounter")
		start_date = start_date.blank? ? "1900-01-01 00:00:00" : start_date.first.start_date
				
		# Query for encounters without obs or orders ~ Kenneth
		ValidationRule.find_by_sql(["
			SELECT DISTINCT (enc.patient_id) FROM encounter enc
    			LEFT JOIN obs o ON o.encounter_id = enc.encounter_id
    			LEFT JOIN orders od ON od.encounter_id = enc.encounter_id
			WHERE enc.voided = 0 AND o.encounter_id IS NULL AND od.encounter_id IS NULL
			AND enc.encounter_datetime BETWEEN ? AND ?", start_date, end_date  
			]).map(&:patient_id)		
		
	end
	
	def self.start_date_before_birth(end_date = Date.today)
		
		start_date = Encounter.find_by_sql("SELECT MIN(encounter_datetime) start_date FROM encounter")
		start_date = start_date.blank? ? "1900-01-01 00:00:00" : start_date.first.start_date
		
		# Query for patients whose earliest start date is less that date of birth ~ Kenneth
		ValidationRule.find_by_sql(["
			SELECT DISTINCT (esd.patient_id) FROM earliest_start_date esd 
   				INNER JOIN person p ON p.person_id = esd.patient_id AND voided = 0
   				INNER JOIN encounter enc ON enc.patient_id = esd.patient_id
			WHERE DATEDIFF(esd.earliest_start_date, p.birthdate) <= 0
			AND enc.encounter_datetime BETWEEN ? AND ?", start_date, end_date  
			]).map(&:patient_id)		
		
	end
	
	def self.visit_after_death(end_date = Date.today)
	
		start_date = Encounter.find_by_sql("SELECT MIN(encounter_datetime) start_date FROM encounter")
		start_date = start_date.blank? ? "1900-01-01 00:00:00" : start_date.first.start_date
		
		#  Query for patients with followup visit after death ~ Kenneth
		ValidationRule.find_by_sql(["
		SELECT DISTINCT(p.person_id) FROM person p 
    		INNER JOIN encounter enc ON enc.patient_id = p.person_id 
				AND enc.voided = 0 AND enc.encounter_datetime > p.death_date
    	WHERE p.dead = 1
			AND enc.encounter_datetime BETWEEN ? AND ?", start_date, end_date  
			]).map(&:person_id)		
			
	end	

  def self.male_patients_with_pregnant_observation(end_date = Date.today)
    @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    pregnant_ids = [ConceptName.find_by_name('PATIENT PREGNANT').concept_id,
                    ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id]

    male_pats_with_preg_obs = PatientProgram.find_by_sql("
                                SELECT esd.patient_id, p.gender,
                                       esd.earliest_start_date, o.concept_id,
                                       o.value_coded, o.obs_datetime
                                FROM earliest_start_date esd
	                                INNER JOIN person p ON p.person_id = esd.patient_id
	                                  AND p.voided = 0
                                  INNER JOIN obs o ON o.person_id = p.person_id
                                    AND o.voided = 0
                                WHERE p.gender = 'M'
                                AND (o.concept_id IN (#{pregnant_ids.join(',')})
                                  OR o.value_coded IN (#{pregnant_ids.join(',')}))
                                AND o.obs_datetime <= '#{@end_date}'
                                GROUP BY esd.patient_id").collect{|p| p.patient_id}
    return male_pats_with_preg_obs
  end

  def self.male_patients_with_breastfeeding_obs(end_date = Date.today)
    @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    breastfeeding_ids = [ConceptName.find_by_name("BREASTFEEDING").concept_id,
                         ConceptName.find_by_name("Currently breastfeeding child").concept_id]

    male_pats_with_breastfeed_obs = PatientProgram.find_by_sql("
                                      SELECT esd.patient_id, p.gender,
                                             esd.earliest_start_date, o.concept_id,
                                             o.value_coded, o.obs_datetime
                                      FROM earliest_start_date esd
	                                      INNER JOIN person p ON p.person_id = esd.patient_id
	                                        AND p.voided = 0
                                        INNER JOIN obs o ON o.person_id = p.person_id
                                         AND o.voided = 0
                                      WHERE p.gender = 'M'
                                      AND (o.concept_id IN (#{breastfeeding_ids.join(',')})
                                        OR o.value_coded IN (#{breastfeeding_ids.join(',')}))
                                      AND o.obs_datetime <= '#{@end_date}'
                                      GROUP BY esd.patient_id").collect{|p| p.patient_id}
    return male_pats_with_breastfeed_obs
  end

  def self.male_patients_with_family_planning_methods_obs(end_date = Date.today)
    @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    family_planing_ids = [ConceptName.find_by_name("FAMILY PLANNING METHOD").concept_id,
                         ConceptName.find_by_name("CURRENTLY USING FAMILY PLANNING METHOD").concept_id]

    male_pats_with_breastfeed_obs = PatientProgram.find_by_sql("
                                      SELECT esd.patient_id, p.gender,
                                             esd.earliest_start_date, o.concept_id,
                                             o.value_coded, o.obs_datetime
                                      FROM earliest_start_date esd
	                                      INNER JOIN person p ON p.person_id = esd.patient_id
	                                        AND p.voided = 0
                                        INNER JOIN obs o ON o.person_id = p.person_id
                                         AND o.voided = 0
                                      WHERE p.gender = 'M'
                                      AND (o.concept_id IN (#{family_planing_ids.join(',')})
                                        OR o.value_coded IN (#{family_planing_ids.join(',')}))
                                      AND o.obs_datetime <= '#{@end_date}'
                                      GROUP BY esd.patient_id").collect{|p| p.patient_id}
    return male_pats_with_breastfeed_obs
  end
end
