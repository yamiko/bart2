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

  def self.pills_remaining_over_dispensed(visit_date)
    visit_date = visit_date.to_date rescue Date.today
    connection = ActiveRecord::Base.connection
    data = {}
    patient_ids = []
    art_adherence_enc = EncounterType.find_by_name('ART ADHERENCE').id
    dispensing_enc = EncounterType.find_by_name('DISPENSING').id
    amount_dispensed_concept = Concept.find_by_name('AMOUNT DISPENSED').id
    amount_brought_to_clinic_concept = Concept.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').id
    adhere_dispensing_encs = connection.select_all("
        SELECT * FROM encounter e WHERE encounter_type IN (#{art_adherence_enc}, #{dispensing_enc})
        AND e.voided=0 AND DATE(e.encounter_datetime) <= \'#{visit_date}\'

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
    
    data.each do |key, values|
      values.each do |patient_id, elements|
        amount_dispensed = elements[:amount_dispensed].to_i
        amount_brought_to_clinic = elements[:amount_brought_to_clinic].to_i
        if (amount_brought_to_clinic > amount_dispensed)
          patient_ids << patient_id
        end
      end
    end

    return patient_ids
  end
  
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
                                  AND DATE(obs_datetime) <= '#{end_date}'
                                  AND voided = 0").length
    return unprescribed
  end

  def self.prescrition_without_dispensation(end_date = Date.today)
    undispensed = Order.find_by_sql("
                                    SELECT DISTINCT(patient_id) FROM orders
                                    WHERE NOT EXISTS (SELECT order_id FROM obs WHERE order_id = orders.order_id
                                    AND concept_id = #{@dispensed_id} and  voided = 0)
                                    AND DATE(start_date)  <= '#{end_date}'
                                    AND orders.voided = 0")
    return undispensed.length
  end

  def self.dispensation_without_appointment(end_date = Date.today)
    no_appointment = Observation.find_by_sql("
                                    SELECT DISTINCT(person_id) FROM obs
                                    WHERE concept_id = #{@dispensed_id}
                                    AND voided = 0
                                    AND DATE(obs_datetime) <= '#{end_date}'
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
    
    total_transferred_in = total_registered - total_reinitiated - total_initiated
    
    total_sum = total_transferred_in + total_reinitiated + total_initiated

    unless total_registered == total_sum
    		return false
    else
    		return true
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

    #Query pulling all male patients with pregnant observations
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

    #Query pulling all male patients with breastfeeding observations
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

    #Query pulling all male patients with family planning methods observations
    male_pats_with_family_planning_obs = PatientProgram.find_by_sql("
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
    return male_pats_with_family_planning_obs
  end

  def self.check_every_ART_patient_has_HIV_Clinical_Registration(date)
			#Task 32
			#SQL to check for every ART patient should have a HIV Clinical Registration

			encounter_type_id = EncounterType.find_by_name("HIV CLINIC REGISTRATION").encounter_type_id

			Patient.find_by_sql("
				SELECT p.patient_id
				FROM earliest_start_date p LEFT JOIN (SELECT * FROM encounter WHERE encounter_type = #{encounter_type_id}) e
						ON p.patient_id = e.patient_id
				WHERE e.encounter_type IS NULL AND p.earliest_start_date <= DATE('#{date}');
			").map(&:patient_id)
	end

end
