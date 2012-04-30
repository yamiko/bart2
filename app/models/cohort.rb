class Cohort
	
	attr :cohort
	attr_accessor :start_date, :end_date, :cohort
	#attr_accessible :cohort

	@@first_registration_date = nil
	@@program_id = nil
  
	# Initialize class
	def initialize(start_date, end_date)
		@start_date = start_date #"#{start_date} 00:00:00"
		@end_date = "#{end_date} 23:59:59"
	
		@@first_registration_date = PatientProgram.find(
		  :first,
		  :conditions =>["program_id = ? AND voided = 0",1],
		  :order => 'date_enrolled ASC'
		).date_enrolled.to_date rescue nil

		@@program_id = Program.find_by_name('HIV PROGRAM').program_id
	end


  def report(logger)
    return {} if @@first_registration_date.blank?
    cohort_report = {}
		threads = []
		threads << Thread.new do
				begin
						cohort_report['Total registrated'] = self.total_registered(@@first_registration_date).length
						cohort_report['Newly total registrated'] = self.total_registered.length
						cohort_report['Total transferred in patients'] = self.transferred_in_patients(@@first_registration_date).length
						cohort_report['Newly transferred in patients'] = self.transferred_in_patients.length
					logger.info("transfered_in " + Time.now.to_s)
					logger.info("male " + Time.now.to_s)
					cohort_report['Newly registrated male'] = self.total_registered_by_gender_age(@start_date,@end_date,'M').length
					cohort_report['Total registrated male'] = self.total_registered_by_gender_age(@@first_registration_date,@end_date,'M').length

					logger.info("non-pregnant " + Time.now.to_s)
					cohort_report['Newly registrated women (non-pregnant)'] = self.non_pregnant_women(@start_date,@end_date).length
					cohort_report['Total registrated women (non-pregnant)'] = self.non_pregnant_women(@@first_registration_date,@end_date).length
				
					logger.info("pregnant " + Time.now.to_s)
					cohort_report['Newly registrated women (pregnant)'] = self.pregnant_women(@start_date,@end_date).length
					cohort_report['Total registrated women (pregnant)'] = self.pregnant_women(@@first_registration_date,@end_date).length

					logger.info("infants " + Time.now.to_s)
					cohort_report['Newly registrated infants'] = self.total_registered_by_gender_age(@start_date,@end_date,nil,0,1.5).length
					cohort_report['Total registrated infants'] = self.total_registered_by_gender_age(@@first_registration_date,@start_date,nil,0,1.5).length

					logger.info("children " + Time.now.to_s)
					cohort_report['Newly registrated children'] = self.total_registered_by_gender_age(@start_date,@end_date,nil,1.5,14).length
					cohort_report['Total registrated children'] = self.total_registered_by_gender_age(@@first_registration_date,@start_date,nil,1.5,14).length

					logger.info("adults " + Time.now.to_s)
					cohort_report['Newly registrated adults'] = self.total_registered_by_gender_age(@start_date,@end_date,nil,14,300).length
					cohort_report['Total registrated adults'] = self.total_registered_by_gender_age(@@first_registration_date,@start_date,nil,14,300).length

				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
    
   
		threads << Thread.new do
		  begin
				logger.info("start_reason " + Time.now.to_s)
				cohort_report['Presumed severe HIV disease in infants'] = 0
				cohort_report['Confirmed HIV infection in infants (PCR)'] = 0
				cohort_report['WHO stage 1 or 2, CD4 below threshold'] = 0
				cohort_report['WHO stage 2, total lymphocytes'] = 0
				cohort_report['Unknown reason'] = 0
				cohort_report['WHO stage 3'] = 0
				cohort_report['WHO stage 4'] = 0
				cohort_report['Patient pregnant'] = 0
				cohort_report['Patient breastfeeding'] = 0
				cohort_report['HIV infected'] = 0

				( self.start_reason || [] ).each do | reason | 
				  if reason.name.match(/Presumed/i)
				    cohort_report['Presumed severe HIV disease in infants'] += 1
				  elsif reason.name.match(/Confirmed/i)
				    cohort_report['Confirmed HIV infection in infants (PCR)'] += 1
				  elsif reason.name[0..11].strip.upcase == 'WHO STAGE I' or reason.name.match(/CD/i)
				    cohort_report['WHO stage 1 or 2, CD4 below threshold'] += 1
				  elsif reason.name[0..12].strip.upcase == 'WHO STAGE II' or reason.name.match(/lymphocytes/i) or reason.name.match(/LYMPHOCYTE/i)
				    cohort_report['WHO stage 2, total lymphocytes'] += 1
				  elsif reason.name[0..13].strip.upcase == 'WHO STAGE III'
				    cohort_report['WHO stage 3'] += 1
				  elsif reason.name[0..11].strip.upcase == 'WHO STAGE IV'
				    cohort_report['WHO stage 4'] += 1
				  elsif reason.name.strip.humanize == 'Patient pregnant'
				    cohort_report['Patient pregnant'] += 1
				  elsif reason.name.match(/Breastfeeding/i)
				    cohort_report['Patient breastfeeding'] += 1
				  elsif reason.name.strip.upcase == 'HIV INFECTED'
				    cohort_report['HIV infected'] += 1
				  else 
				    cohort_report['Unknown reason'] += 1
				  end
				end
				
				cohort_report['Total Presumed severe HIV disease in infants'] = 0
				cohort_report['Total Confirmed HIV infection in infants (PCR)'] = 0
				cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] = 0
				cohort_report['Total WHO stage 2, total lymphocytes'] = 0
				cohort_report['Total Unknown reason'] = 0
				cohort_report['Total WHO stage 3'] = 0
				cohort_report['Total WHO stage 4'] = 0
				cohort_report['Total Patient pregnant'] = 0
				cohort_report['Total Patient breastfeeding'] = 0
				cohort_report['Total HIV infected'] = 0

				( self.start_reason(@@first_registration_date,@end_date) || [] ).each do | reason | 
				  if reason.name.match(/Presumed/i)
				    cohort_report['Total Presumed severe HIV disease in infants'] += 1
				  elsif reason.name.match(/Confirmed/i)
				    cohort_report['Total Confirmed HIV infection in infants (PCR)'] += 1
				  elsif reason.name[0..11].strip.upcase == 'WHO STAGE I' or reason.name.match(/CD/i)
				    cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] += 1
				  elsif reason.name[0..12].strip.upcase == 'WHO STAGE II' or reason.name.match(/lymphocytes/i) or reason.name.match(/LYMPHOCYTE/i)
				    cohort_report['Total WHO stage 2, total lymphocytes'] += 1
				  elsif reason.name[0..13].strip.upcase == 'WHO STAGE III'
				    cohort_report['Total WHO stage 3'] += 1
				  elsif reason.name[0..11].strip.upcase == 'WHO STAGE IV'
				    cohort_report['Total WHO stage 4'] += 1
				  elsif reason.name.strip.humanize == 'Patient pregnant'
				    cohort_report['Total Patient pregnant'] += 1
				  elsif reason.name.match(/Breastfeeding/i)
				    cohort_report['Total Patient breastfeeding'] += 1
				  elsif reason.name.strip.upcase == 'HIV INFECTED'
				    cohort_report['Total HIV infected'] += 1
				  else 
				    cohort_report['Total Unknown reason'] += 1
				  end
				end
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end
		  
		  
		threads << Thread.new do
		  begin
				logger.info("tb_within_last_year " + Time.now.to_s)
				cohort_report['TB within the last 2 years'] = self.tb_within_the_last_2_yrs.length
				cohort_report['Total TB within the last 2 years'] = self.tb_within_the_last_2_yrs(@@first_registration_date,@end_date).length

				logger.info("current_episode_of_tb " + Time.now.to_s)
				cohort_report['Current episode of TB'] = self.current_espisode_of_tb.length
				cohort_report['Total Current episode of TB'] = self.current_espisode_of_tb(@@first_registration_date,@end_date).length

				logger.info("ks " + Time.now.to_s)
				cohort_report['Kaposis Sarcoma'] = self.kaposis_sarcoma.length
				cohort_report['Total Kaposis Sarcoma'] = self.kaposis_sarcoma(@@first_registration_date,@end_date).length

				logger.info("no_tb " + Time.now.to_s)
				cohort_report['No TB'] = (cohort_report['Newly total registrated'] - (cohort_report['Current episode of TB'] + cohort_report['TB within the last 2 years']))
				cohort_report['Total No TB'] = (cohort_report['Total registrated'] - (cohort_report['Total Current episode of TB'] + cohort_report['Total TB within the last 2 years']))

				logger.info("alive_on_art " + Time.now.to_s)
				cohort_report['Total alive and on ART'] = self.total_alive_and_on_art.length
				cohort_report['Died total'] = self.total_number_of_dead_patients

				logger.info("death_dates " + Time.now.to_s)
				death_dates_array = self.death_dates
				cohort_report['Died within the 1st month after ART initiation'] = death_dates_array[0].length
				cohort_report['Died within the 2nd month after ART initiation'] = death_dates_array[1].length
				cohort_report['Died within the 3rd month after ART initiation'] = death_dates_array[2].length
				cohort_report['Died after the end of the 3rd month after ART initiation'] = death_dates_array[3].length
				
				death_dates_array = self.death_dates(@@first_registration_date,@end_date)
				cohort_report['Total Died within the 1st month after ART initiation'] = death_dates_array[0].length
				cohort_report['Total Died within the 2nd month after ART initiation'] = death_dates_array[1].length
				cohort_report['Total Died within the 3rd month after ART initiation'] = death_dates_array[2].length
				cohort_report['Total Died after the end of the 3rd month after ART initiation'] = death_dates_array[3].length

				logger.info("txfrd_out " + Time.now.to_s)
				cohort_report['Transferred out'] = self.transferred_out_patients
				
				logger.info("stopped_arvs " + Time.now.to_s)
				cohort_report['Stopped taking ARVs'] = self.art_stopped_patients
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
		  begin
				logger.info("defaulted " + Time.now.to_s)    
				cohort_report['Defaulted'] = self.art_defaulted_patients

				logger.info("tb_status " + Time.now.to_s)
				tb_status_outcomes = self.tb_status
				cohort_report['TB suspected'] = tb_status_outcomes['TB STATUS']['Suspected']
				cohort_report['TB not suspected'] = tb_status_outcomes['TB STATUS']['Not Suspected']
				cohort_report['TB confirmed not treatment'] = tb_status_outcomes['TB STATUS']['Not on treatment']
				cohort_report['TB confirmed on treatment'] = tb_status_outcomes['TB STATUS']['On Treatment']
				cohort_report['TB Unknown'] = tb_status_outcomes['TB STATUS']['Unknown']
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
		  begin
				logger.info("regimens " + Time.now.to_s)
				cohort_report['Regimens'] = self.regimens(@@first_registration_date)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
		  begin
				logger.info("reinitiated_on_art " + Time.now.to_s)    
				cohort_report['Patients reinitiated on ART'] = self.patients_reinitiated_on_art.length
				cohort_report['Total Patients reinitiated on ART'] = self.patients_reinitiated_on_art(@@first_registration_date).length

				logger.info("initiated_on_art " + Time.now.to_s)  
				cohort_report['Patients initiated on ART'] = self.patients_initiated_on_art_first_time.length
				cohort_report['Total Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@@first_registration_date).length
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads.each do |thread|
			 thread.join
			 if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].to_yaml
			 end
		end

    self.cohort = cohort_report
    self.cohort

  end

	def total_registered(start_date = @start_date, end_date = @end_date)
    #start_date = @start_date
    #end_date = @end_date
    on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      on_art_concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id
		
	PatientProgram.find_by_sql("SELECT p.patient_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(s.start_date) AS earliest_start_date, MIN(o.value_datetime) AS original_start_date
		FROM patient_program p
			LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
			LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
			LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
		WHERE p.voided = 0
			AND s.voided = 0
			AND program_id = #{@@program_id}
			AND s.state = #{state}
		GROUP BY p.patient_id
		HAVING 
			earliest_start_date >= '#{start_date}'
			AND earliest_start_date <= '#{end_date}'")
=begin    
    PatientProgram.find_by_sql("SELECT patient_id FROM patient_program p
                                INNER JOIN patient_state s USING (patient_program_id)
                                WHERE p.voided = 0
                                AND s.voided = 0
                                AND program_id = #{@@program_id}
                                AND s.state = #{state}
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}'
                                GROUP BY patient_id ORDER BY date_enrolled")#.length rescue 0
=end  
  end

	  def patients_initiated_on_art_first_time(start_date = @start_date, end_date = @end_date)
    no_concept = ConceptName.find_by_name('NO')
    #ever_received_concept_id = ConceptName.find_by_name("EVER RECEIVED ART").concept_id
    on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      on_art_concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id

    PatientProgram.find_by_sql("SELECT p.patient_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(s.start_date) AS earliest_start_date, MIN(o.value_datetime) AS original_start_date
		FROM patient_program p
			LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
			LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
			LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
		WHERE p.voided = 0
			AND s.voided = 0
			AND program_id = #{@@program_id}
			AND s.state = #{state}
		GROUP BY p.patient_id
		HAVING 
			earliest_start_date >= '#{start_date}'
			AND earliest_start_date <= '#{end_date}'
			AND	original_start_date IS NULL")
    
=begin
    
    PatientProgram.find_by_sql("SELECT 
															 p.patient_id ,obs.obs_datetime visit_date,obs.value_coded, obs.value_text,obs.concept_id concept_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date
			FROM obs
				LEFT JOIN patient_program p ON p.patient_id = obs.person_id
				LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
				LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
				LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id 
			WHERE p.program_id = #{@@program_id}
				AND obs.concept_id = #{ever_received_concept_id}
				AND obs.value_text = #{no_concept.concept_id}
				AND e.encounter_datetime >= '#{start_date}'
				AND e.encounter_datetime <= '#{end_date}' 
			GROUP BY patient_id
			HAVING 
				earliest_start_date >= '#{start_date}'
				AND earliest_start_date <= '#{end_date}'
				AND	original_start_date IS NULL")
				
				# rescue 0
=end    
      
  end

	def patients_reinitiated_on_art(start_date = @start_date, end_date = @end_date)
    patients = []
    
		no_concept = ConceptName.find_by_name('NO').concept_id
    date_art_last_taken_concept = ConceptName.find_by_name('DATE ART LAST TAKEN').concept_id

    taken_arvs_concept = ConceptName.find_by_name('HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS').concept_id
    
    defaulted = ConceptName.find_all_by_name("DEFAULTED")
    defaulted_state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      defaulted.map{|c|c.concept_id}]
    ).program_workflow_state_id

		treatment_stopped = ConceptName.find_all_by_name("TREATMENT STOPPED")
    treatment_stopped_state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      treatment_stopped.map{|c|c.concept_id}]
    ).program_workflow_state_id
    
   	PatientProgram.find_by_sql("SELECT patient_id , value_datetime date_art_last_taken,obs_datetime visit_date,value_coded,obs.concept_id concept_id  
                                FROM obs 
                                LEFT JOIN patient_program p ON p.patient_id = obs.person_id
                                LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                WHERE p.program_id = #{@@program_id} 
                                AND (obs.concept_id = #{date_art_last_taken_concept}
                                OR obs.concept_id = #{taken_arvs_concept})
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}'
                                GROUP BY patient_id
                                ORDER BY obs.obs_datetime DESC").map do |ob| 
                                	if ob.concept_id.to_s == date_art_last_taken_concept.to_s
																		patient_program_id = PatientProgram.find_by_patient_id(ob.patient_id).patient_program_id
																		state = PatientState.find(:all, :conditions => ["patient_program_id = #{patient_program_id} AND end_date IS NOT NULL"], :order => 'date_created ASC').last rescue 0 
																		if !state.blank?
																			if (state.state == "#{defaulted_state}" || state.state == "#{treatment_stopped_state}")
																			
																				unless 4 >= ((ob.visit_date.to_date - ob.date_art_last_taken.to_date) / 7).to_i
																					patients << ob
																				end
																			end
																		end
																	elsif ob.value_coded.to_s == no_concept.to_s
																	  patients << ob
																	end
                                end
    return patients

  end


	def transferred_in_patients(start_date = @start_date, end_date = @end_date)
    #ever_received_concept_id = ConceptName.find_by_name("EVER RECEIVED ART").concept_id
    #ever_registered_at_a_clinic = Concept.find_by_name("EVER REGISTERED AT ART CLINIC").concept_id

    #yes_concept_id = ConceptName.find_by_name("YES").concept_id

=begin
    PatientProgram.find_by_sql("SELECT 
                                patient_id ,obs_datetime visit_date,value_coded,obs.concept_id concept_id  
                                FROM obs 
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN obs ON obs.person_id = p.patient_id 
                                WHERE p.voided = 0
                                AND s.voided = 0
                                AND program_id = 1
                                AND obs.voided = 0
                                AND patient_start_date(p.patient_id) >= '#{start_date}'
                                AND patient_start_date(p.patient_id) <= '#{end_date}'
                                AND obs.concept_id = #{ever_received_concept_id}
                                AND value_coded = #{yes_concept_id}
                                GROUP BY patient_id") rescue 0
=end
				on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
						state = ProgramWorkflowState.find(
							:first,
							:conditions => ["concept_id IN (?)",
								              on_art_concept_name.map{|c|c.concept_id}]
						).program_workflow_state_id
    
					PatientProgram.find_by_sql("SELECT p.patient_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(s.start_date) AS earliest_start_date, MIN(o.value_datetime) AS original_start_date
							FROM patient_program p
								LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
								LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
								LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
							WHERE p.voided = 0
								AND s.voided = 0
								AND program_id = #{@@program_id}
								AND s.state = #{state}
							GROUP BY p.patient_id
							HAVING 
								earliest_start_date >= '#{start_date}'
								AND earliest_start_date <= '#{end_date}'
								AND	original_start_date IS NOT NULL")
		end

 	def total_registered_by_gender_age(start_date = @start_date, end_date = @end_date, sex = nil, min_age = nil, max_age = nil)
    yes_concept_id = ConceptName.find_by_name("YES").concept_id
    conditions = ''

    if min_age or max_age
      conditions = "AND TRUNCATE(DATEDIFF(date_enrolled, person.birthdate)/365,0) >= #{min_age}
                    AND TRUNCATE(DATEDIFF(date_enrolled, person.birthdate)/365,0) <= #{max_age}"
    end

    if sex
      conditions += " AND person.gender = '#{sex}'"
    end

		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		
		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
			on_art_concept_name.map{|c|c.concept_id}]
		).program_workflow_state_id    
=begin
    PatientProgram.find_by_sql("SELECT patient_id,program_id,count(*) FROM patient_program p
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN obs ON obs.person_id = p.patient_id 
                                INNER JOIN person ON person.person_id = p.patient_id 
                                WHERE p.voided = 0
                                AND s.voided = 0
                                AND program_id = 1
                                AND obs.voided = 0
                                AND patient_start_date(p.patient_id) >= '#{start_date}'
                                AND patient_start_date(p.patient_id) <= '#{end_date}'
                                #{conditions} GROUP BY patient_id")
=end
		PatientProgram.find_by_sql("SELECT p.patient_id,person.gender, program_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(s.start_date) AS earliest_start_date, MIN(o.value_datetime) AS original_start_date, count(*) FROM patient_program p
			 	LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
				LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
				LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
			 	LEFT JOIN person ON person.person_id = p.patient_id 
			 	WHERE p.voided = 0
				 	AND s.voided = 0
				 	AND program_id = #{@@program_id}
				 	AND state = #{state}
				 	#{conditions}
			 	GROUP BY patient_id
			 	HAVING 
				 	earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'")
  end

	def non_pregnant_women(start_date = @start_date, end_date = @end_date)
    all_women =  self.total_registered_by_gender_age(start_date,end_date,'F').map{|patient| patient.patient_id}
    non_pregnant_women = (all_women - self.pregnant_women(start_date,end_date).map{|patient| patient.patient_id})
  end

	def pregnant_women(start_date = @start_date, end_date = @end_date)
    #pregnant_concept_id = ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
    #pmtct_concept_id = ConceptName.find_by_name("REFERRED BY PMTCT").concept_id
    yes_concept_id = ConceptName.find_by_name("YES").concept_id

		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		
		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
			on_art_concept_name.map{|c|c.concept_id}]
		).program_workflow_state_id    
=begin

    PatientProgram.find_by_sql("SELECT patient_id,date_enrolled,obs.concept_id FROM obs 
                                LEFT JOIN patient_program p ON p.patient_id = obs.person_id
                                LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                LEFT JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = 1
                                AND gender ='F' 
                                AND s.start_date >= '#{start_date}'
                                AND s.start_date <= '#{end_date}' 
                                AND ((obs.concept_id = #{pregnant_concept_id}
                                AND obs.value_coded = #{yes_concept_id} )) 
                                AND (DATEDIFF(DATE(obs.obs_datetime), date_enrolled) >= 0) 
                                AND DATEDIFF(DATE(obs.obs_datetime),date_enrolled) <= 30
                                GROUP BY patient_id")
=end
						PatientProgram.find_by_sql("SELECT patient_id,date_enrolled,o.concept_id, o.value_coded FROM obs 
						 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
						 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
						 LEFT JOIN patient_pregnant_observation o ON o.person_id = p.patient_id 
						 WHERE p.program_id = 1
						 AND o.obs_datetime >= '#{start_date}'
						 AND o.obs_datetime <= '#{end_date}' 
						 AND o.value_coded = #{yes_concept_id}
						 AND s.state = #{state} 
						 GROUP BY patient_id")
  end

  def start_reason(start_date = @start_date, end_date = @end_date)
    start_reason_hash = Hash.new(0)
    reason_concept_id = ConceptName.find_by_name("REASON FOR ART ELIGIBILITY").concept_id

		PatientProgram.find_by_sql("SELECT p.patient_id,name,date_enrolled, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date FROM obs
																 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
																 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
																 LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
																 LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
																 LEFT JOIN concept_name n ON n.concept_id = obs.value_coded
																 WHERE s.start_date >= '#{start_date}'
																 AND s.start_date <= '#{end_date}'
																 AND obs.concept_id = #{reason_concept_id}
																 AND p.program_id = #{@@program_id}
																 AND n.name != ''
																 GROUP BY patient_id")

=begin
    PatientProgram.find_by_sql("SELECT patient_id,name,date_enrolled FROM obs
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN concept_name n ON n.concept_id = obs.value_coded
                                WHERE patient_start_date(patient_id) >='#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}' 
                                AND obs.concept_id = #{reason_concept_id}
                                AND p.program_id = #{@@program_id}
                                AND n.name != ''
                                GROUP BY patient_id")
=end
  end

	def tb_within_the_last_2_yrs(start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("PULMONARY TUBERCULOSIS WITHIN THE LAST 2 YEARS").concept_id
    self.patients_with_start_cause(start_date,end_date,tb_concept_id)
  end
  
  def current_espisode_of_tb(start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("EXTRAPULMONARY TUBERCULOSIS (EPTB)").concept_id
    self.patients_with_start_cause(start_date,end_date,tb_concept_id)
  end

	def kaposis_sarcoma(start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("KAPOSIS SARCOMA").concept_id
    self.patients_with_start_cause(start_date,end_date,tb_concept_id)
  end

  def patients_with_start_cause(start_date = @start_date,end_date = @end_date, tb_concept_id = nil)
    return if tb_concept_id.blank?
    cause_concept_id = ConceptName.find_by_name("WHO STG CRIT").concept_id
=begin
    PatientProgram.find_by_sql("SELECT patient_id,name,date_enrolled FROM obs
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN concept_name n ON n.concept_id = obs.value_coded
                                WHERE patient_start_date(patient_id) >='#{start_date}' AND patient_start_date(patient_id) <= '#{end_date}' 
                                AND obs.concept_id = #{cause_concept_id} AND p.program_id = #{@@program_id}
                                AND obs.value_coded = #{tb_concept_id} GROUP BY patient_id")#.length
=end
		PatientProgram.find_by_sql("SELECT p.patient_id,name,date_enrolled, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date FROM obs
																 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
																 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
																 LEFT JOIN concept_name n ON n.concept_id = obs.value_coded
																 LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
																 LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
																 WHERE s.start_date >='#{start_date}'
																 AND s.start_date <= '#{end_date}'
																 AND obs.concept_id = #{cause_concept_id}
																 AND p.program_id = #{@@program_id}
																 AND obs.value_coded = #{tb_concept_id}
																 GROUP BY patient_id")
  end

  def total_alive_and_on_art
    on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      on_art_concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id

    PatientState.find_by_sql("SELECT * FROM (
        SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
               n.name name,state
        FROM patient_state s
        LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        LEFT JOIN program_workflow pw ON pw.program_id = p.program_id
        LEFT JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
        AND w.program_workflow_state_id = s.state
        LEFT JOIN concept_name n ON w.concept_id = n.concept_id
        WHERE p.voided = 0 AND s.voided = 0
        AND (s.start_date >= '#{@@first_registration_date}'
        AND s.start_date <= '#{@end_date}')
        AND p.program_id = #{@@program_id}
        ORDER BY patient_state_id DESC, start_date DESC
      ) K
      GROUP BY K.patient_id HAVING (state = #{state})
      ORDER BY K.patient_state_id DESC, K.start_date DESC")
  end

  def death_dates(start_date = @start_date, end_date = @end_date)
    start_date_death_date = [] 

    first_month = [] ; second_month = [] ; third_month = [] ; after_third_month = []

    first_month_date = [start_date.to_date,(start_date.to_date + 1.month)]
    second_month_date = [first_month_date[1],first_month_date[1] + 1.month]
    third_month_date = [second_month_date[1],second_month_date[1] + 1.month]

    ( self.died_total || [] ).each do | state |
      if (state.date_enrolled.to_date >= first_month_date[0]  and state.date_enrolled.to_date <= first_month_date[1] )
          first_month << state
      elsif (state.date_enrolled.to_date >= second_month_date[0]  and state.date_enrolled.to_date <= second_month_date[1] )
          second_month << state
      elsif (state.date_enrolled.to_date >= third_month_date[0]  and state.date_enrolled.to_date <= third_month_date[1] )
          third_month << state
      elsif (state.date_enrolled.to_date > third_month_date[1] )
          after_third_month << state
      end
    end
    [first_month, second_month, third_month, after_third_month]
  end
  
  def total_number_of_dead_patients
    self.outcomes_total('PATIENT DIED').length
  end

	def died_total
    self.outcomes_total('PATIENT DIED')
  end

  def art_defaulted_patients
    self.outcomes_total('DEFAULTED').length
  end

  def art_stopped_patients
    self.outcomes_total('TREATMENT STOPPED').length
  end

  def transferred_out_patients
    self.outcomes_total('PATIENT TRANSFERRED OUT').length
  end

  def outcomes_total(outcome)
    on_art_concept_name = ConceptName.find_all_by_name(outcome)
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      on_art_concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id

    PatientState.find_by_sql("SELECT * FROM (
        SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
               n.name name,state,p.date_enrolled date_enrolled
        FROM patient_state s
        LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        LEFT JOIN program_workflow pw ON pw.program_id = p.program_id
        LEFT JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
        AND w.program_workflow_state_id = s.state
        LEFT JOIN concept_name n ON w.concept_id = n.concept_id
        WHERE p.voided = 0 AND s.voided = 0
        AND (s.start_date >= '#{@@first_registration_date}'
        AND s.start_date <= '#{@end_date}')
        AND p.program_id = #{@@program_id}
        ORDER BY patient_state_id DESC, start_date DESC
      ) K
      GROUP BY K.patient_id HAVING (state = #{state})
      ORDER BY K.patient_state_id DESC, K.start_date DESC")
  end

  def regimens(start_date = @start_date, end_date = @end_date)
    regimens = []
    regimen_hash = {}

    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT')
=begin
    PatientProgram.find_by_sql("SELECT patient_id , value_coded regimen_id, value_text regimen ,
                                age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
                                LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension  
                                FROM obs 
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = #{end_date} AND obs.concept_id = #{regimem_given_concept.concept_id}
                                AND patient_start_date(patient_id) >= '#{start_date}' AND patient_start_date(patient_id) <= '#{end_date}' 
                                GROUP BY patient_id 
                                ORDER BY obs.obs_datetime DESC")
=end

		PatientProgram.find_by_sql("SELECT patient_id , obs.value_coded regimen_id, obs.value_text regimen ,
																	 age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
																	 LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension 
																	 FROM obs 
																	 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
																	 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
																	 LEFT JOIN person ON person.person_id = p.patient_id
																	 WHERE p.program_id = #{@@program_id} AND obs.concept_id = #{regimem_given_concept.concept_id}
																	 AND s.start_date >= '#{start_date}' AND s.start_date <= '#{end_date}' 
																	 GROUP BY patient_id 
																	 ORDER BY obs.obs_datetime DESC ").each do | value | 
                                  regimens << [value.regimen_id, 
                                               value.regimen,
                                               value.person_age_at_drug_dispension
                                              ]
                                end
    ( regimens || [] ).each do | regimen_id, regimen , patient_age |
      age = patient_age.to_i 
      regimen_name = ConceptName.find_by_concept_id(regimen_id).concept.shortname rescue nil
      if regimen_name.blank?
        regimen_name = ConceptName.find_by_concept_id(regimen_id).concept.fullname 
      end

      regimen_name = cohort_regimen_name(regimen_name,age)

      if regimen_hash[regimen_name].blank?
        regimen_hash[regimen_name] = 0
      end
      regimen_hash[regimen_name]+=1
    end
    regimen_hash
  end

  def side_effect_patients(start_date = @start_date, end_date = @end_date)
    side_effect_concept_ids =[ConceptName.find_by_name('PERIPHERAL NEUROPATHY').concept_id,
                              ConceptName.find_by_name('HEPATITIS').concept_id,
                              ConceptName.find_by_name('SKIN RASH').concept_id,
                              ConceptName.find_by_name('JAUNDICE').concept_id]

    encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
    concept_id = ConceptName.find_by_name('SYMPTOM PRESENT').concept_id

    encounter_ids = Encounter.find(:all,:conditions => ["encounter_type = ? 
                    AND (patient_start_date(patient_id) >= '#{start_date}'
                    AND patient_start_date(patient_id) <= '#{end_date}')
                    AND (encounter_datetime >= '#{start_date}'
                    AND encounter_datetime <= '#{end_date}')",
                    encounter_type.id],:group => 'patient_id',:order => 'encounter_datetime DESC').map{| e | e.encounter_id }

    Observation.find(:all,
                     :conditions => ["encounter_id IN (#{encounter_ids.join(',')})
                     AND concept_id = ? 
                     AND value_coded IN (#{side_effect_concept_ids.join(',')})",concept_id],
                     :group =>'person_id').length
  end

  def tb_status
    tb_status_hash = {} ; status = []
    tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0} 
    tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id   
                          
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end                          
				           status = PatientState.find_by_sql("SELECT e.patient_id,n.name tbstatus,obs.obs_datetime,e.encounter_datetime,s.state
														 FROM patient_state s
														 LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id 
														 LEFT JOIN clinic_consultation_encounter e ON e.patient_id = p.patient_id
														 LEFT JOIN tb_status_observations obs ON obs.encounter_id = e.encounter_id
														 LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
														 WHERE p.voided = 0
														 AND s.voided = 0
														 AND obs.obs_datetime = e.encounter_datetime
														 AND (s.start_date >= '#{@@first_registration_date}'
														 AND s.start_date <= '#{@end_date}')
														 AND obs.concept_id = #{tb_status_concept_id}
														 AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
														 AND p.program_id = #{@@program_id}
														 GROUP By obs.person_id
														 ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC") .map(&:tbstatus)

    ( status || [] ).each do | state |
      if state == 'TB NOT SUSPECTED' or state == 'noSusp' or state == 'noSup' or state == 'TB not suspected' or state == 'TB NOT suspected' or state == 'Nosup'
        tb_status_hash['TB STATUS']['Not Suspected'] += 1
      elsif state == 'TB SUSPECTED' or state == 'susp' or state == 'sup' or state == 'TB suspected' or state == 'Tb suspected'
        tb_status_hash['TB STATUS']['Suspected'] += 1
      elsif state == 'RX' or state == 'CONFIRMED TB ON TREATMENT' or state == 'Rx' or state == 'CONFIRMED TB ON TREATMENT' or state == 'Confirmed TB on treatment' or state == 'Confirmed TB on treatment' or state == 'Norx'
        tb_status_hash['TB STATUS']['On Treatment'] += 1
      elsif state == 'noRX' or state == 'CONFIRMED TB NOT ON TREATMENT' or state =='Confirmed TB not on treatment' or state == 'Confirmed TB NOT on treatment'
        tb_status_hash['TB STATUS']['Not on treatment'] += 1
      else
        tb_status_hash['TB STATUS']['Unknown'] += 1
      end
    end
    tb_status_hash
  end

	# Get patients reinitiated on art count
	def patients_reinitiated_on_art_ever
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?", ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
			ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
			@end_date.to_date.strftime("%Y-%m-%d")]).length rescue 0
	end

  def patients_reinitiated_on_arts
    Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
        AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') >= ? AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?",
        ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
        ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
        @start_date.to_date.strftime("%Y-%m-%d"), @end_date.to_date.strftime("%Y-%m-%d")]).length rescue 0
  end

  def outcomes(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date, program_id = @@program_id, min_age=nil, max_age=nil,states = [])

    if min_age or max_age
      conditions = "AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) >= #{min_age}
                    AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) <= #{max_age}"
    end

    PatientState.find_by_sql("SELECT * FROM (
        SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
               n.name name,state
        FROM patient_state s
        INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        INNER JOIN program_workflow pw ON pw.program_id = p.program_id
        INNER JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
                   AND w.program_workflow_state_id = s.state
        INNER JOIN concept_name n ON w.concept_id = n.concept_id
        INNER JOIN person ON person.person_id = p.patient_id
        WHERE p.voided = 0 AND s.voided = 0 #{conditions}
        AND (patient_start_date(patient_id) >= '#{start_date}'
        AND patient_start_date(patient_id) <= '#{end_date}')
        AND p.program_id = #{program_id}
        AND s.start_date <= '#{outcome_end_date}'
        ORDER BY patient_id DESC, patient_state_id DESC, start_date DESC
      ) K
      GROUP BY patient_id
      ORDER BY K.patient_state_id DESC , K.start_date DESC").map do |state|
        states << [state.patient_id , state.name]
      end
  end

  def first_registration_date
    @@first_registration_date
  end
  
  def regimens_with_patient_ids(start_date = @start_date, end_date = @end_date)
    regimens = []
    regimen_hash = {}

    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT')
    PatientProgram.find_by_sql("SELECT patient_id , value_coded regimen_id, value_text regimen ,
                                age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
                                LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension  
                                FROM obs 
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = #{@@program_id}
                                AND obs.concept_id = #{regimem_given_concept.concept_id}
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}' 
                                GROUP BY patient_id 
                                ORDER BY obs.obs_datetime DESC").each do | value |
                                  if value.regimen.blank?
																		value.regimen = ConceptName.find_by_concept_id(value.regimen_id).concept.shortname								
		                                regimens << [value.regimen_id, 
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              else
		                              	regimens << [value.regimen_id, 
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              end
                                end
  end

	def adherence(start_date = @start_date, end_date = @end_date)

		#loop through each patient with adherence encounter
		art_adherence = EncounterType.find_by_name('ART ADHERENCE').id
		pills_left_ids = [ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id,
											  ConceptName.find_by_name("AMOUNT OF DRUG REMAINING AT HOME").concept_id]
		
		encounters = Encounter.find(:all, :conditions => ["encounter_type = #{art_adherence}"], :limit => 500)#

		counter = 0
		encounters.map do |adherence|

			orders = PatientService.drug_given_before(adherence.patient, adherence.encounter_datetime)

			orders.map do |order| 
				amount_brought_to_clinic = 0
				adherence.observations.map do |obs|
					if pills_left_ids.include?(obs.concept_id) && order.order_id == obs.order_id
						amount_brought_to_clinic += obs.answer_string.to_i
					end

				end

				num_days = (adherence.encounter_datetime.to_date - order.start_date.to_date).to_i#/ (1000 * 60 * 60 * 24)

				if order.drug_order.quantity 
					order_quantity = order.drug_order.quantity
				else
					order_quantity = 0
				end

				expected_amount_remaining = (order_quantity - (num_days * order.drug_order.equivalent_daily_dose.to_i))

				if expected_amount_remaining == amount_brought_to_clinic
		    	doses_missed = 0
		    else
		    	doses_missed = ((expected_amount_remaining - amount_brought_to_clinic) / order.drug_order.equivalent_daily_dose.to_i)#.to_i
		    	if doses_missed < 0
		    		doses_missed = doses_missed * -1
		    	else
		    		doses_missed
		    	end
		    end
		    
		    observation = Observation.new
				observation.person_id = adherence.patient_id
				observation.encounter_id = adherence.encounter_id
				observation.concept_id = ConceptName.find_by_name("MISSED HIV DRUG CONSTRUCT").concept_id
				observation.obs_datetime = adherence.encounter_datetime
				observation.value_numeric = doses_missed.to_i
				observation.order_id = order.order_id
				observation.location_id = adherence.location_id
				if observation.save
					counter += 1
				end
			end
		end
		return counter
	end

  def tb_status_with_patient_ids
    tb_status_hash = {} ; status = []
    tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0} 
    tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id   
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end
		status = PatientState.find_by_sql("SELECT e.patient_id,n.name tbstatus,obs.obs_datetime,e.encounter_datetime,s.state
																			 FROM patient_state s
																			 LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id 
																			 LEFT JOIN clinic_consultation_encounter e ON e.patient_id = p.patient_id
																			 LEFT JOIN tb_status_observations obs ON obs.encounter_id = e.encounter_id
																			 LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
																			 WHERE p.voided = 0
																			 AND s.voided = 0
																			 AND obs.obs_datetime = e.encounter_datetime
																			 AND (s.start_date >= '#{@@first_registration_date}'
																			 AND s.start_date <= '#{@end_date}')
																			 AND obs.concept_id = #{tb_status_concept_id}
																			 AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
																			 AND p.program_id = #{@@program_id}
																			 GROUP By obs.person_id
	 ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC")  
  end

  private

  def cohort_regimen_name(name , age)
    case name
      when 'd4T/3TC/NVP'
        return 'A1' if age > 14
        return 'P1'
      when 'd4T/3TC + d4T/3TC/NVP (Starter pack)'
        return 'A1' if age > 14
        return 'P1'
      when 'AZT/3TC/NVP'
        return 'A2' if age > 14
        return 'P2'
      when 'AZT/3TC + AZT/3TC/NVP (Starter pack)'
        return 'A2' if age > 14
        return 'P2'
      when 'd4T/3TC/EFV'
        return 'A3' if age > 14
        return 'P3'
      when 'AZT/3TC+EFV'
        return 'A4' if age > 14
        return 'P4'
      when 'TDF/3TC/EFV'
        return 'A5' if age > 14
        return 'P5'
      when 'TDF/3TC+NVP'
        return 'A6' if age > 14
        return 'P6'
      when 'TDF/3TC+LPV/r'
        return 'A7' if age > 14
        return 'P7'
      when 'AZT/3TC+LPV/r'
        return 'A8' if age > 14
        return 'P8'
      when 'ABC/3TC+LPV/r'
        return 'A9' if age > 14
        return 'P9'
      else
        return 'UNKNOWN ANTIRETROVIRAL DRUG'
    end
  end
end
