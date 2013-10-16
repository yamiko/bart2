=begin

Creator 	:     	Precious Ulemu Bondwe
Date    	:     	2013-10-11 
Purpose 	:     	The script is meant to fix the encounters that failed to follow the rule of getting latest 
					encounters in case of multiple occurences on the same day
pre-requisite	:	This script is only meant for area 25 urban health center. DO NOT RUN ON ANY OTHER DATASET
amendments	:	********** INCLUDE AMENDMENTS HERE  ***************
=end

def init_variables
	Source_db = 'bart1_area_25'
	Target_db = 'bart2_area_25'
end

def start
	init_variables
	count = 0
	all_patients = Patient.find_by_sql("SELECT 
											e.patient_id,
											count(e.patient_id) as count,
											e.encounter_datetime
										FROM
											encounter e
										WHERE
											e.encounter_type = 2 
										group by e.patient_id , DATE(e.encounter_datetime)
										having count > 1")

	puts "Patients with duplicate ARV Encounters >>>>>>>> #{all_patients.count}"

	(all_patients || []).each do |pat|
	
		encounters = Encounter.find_by_sql("Select e.* from #{Source_db}.encounter e
		                                      inner join #{Source_db}.obs o on e.encounter_id = o.encounter_id
		                                    where e.patient_id = #{pat.patient.id}
		                                    and o.voided = 0
		                                    and e.date_created = (select max(date_created) 
		                                                          from encounter 
		                                                          where encounter_type = e.encounter_type
		                                                          and patient_id = e.patient_id)
		                                    group by e.encounter_id")


		(encounters || []).each do |enc|
			equivalent_encounter = Encounter.find(enc.encounter_id)
			
			if equivalent_encounter.blank?
				count = count + 1
				puts "we need to update existing encount with encounter details for >>> #{enc.}"
			end
		end
	end
	puts "Total Number of encounters to be updated >>>> #{count}"
end

start
