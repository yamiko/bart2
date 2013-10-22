=begin

Creator 	:     	Precious Ulemu Bondwe
Date    	:     	2013-10-11 
Purpose 	:     	The script is meant to fix the encounters that failed to follow the rule of getting latest 
					encounters in case of multiple occurences on the same day
pre-requisite	:	This script is only meant for area 25 urban health center. DO NOT RUN ON ANY OTHER DATASET
amendments	:	********** INCLUDE AMENDMENTS HERE  ***************
=end

def init_variables
	source_db = 'bart1_area_25'
	target_db = 'area_25_to_be_fixed'
	art_visit_encounter_type = 2
	hiv_clinic_encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION").id

	concept_map = {}
	
end

def start
#	init_variables
	source_db = 'bart1_area_25'
	target_db = 'area_25_to_be_fixed'
	art_visit_encounter_type = 2
	hiv_clinic_encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION").id
	encounters_to_import = []
	encounters_to_void = []
	count = 0

	all_patients = Patient.find_by_sql("SELECT 
											e.patient_id,
											count(e.patient_id) as count,
											e.encounter_datetime
										FROM
											#{source_db}.encounter e
										WHERE
											e.encounter_type = #{art_visit_encounter_type} 
										group by e.patient_id , DATE(e.encounter_datetime)
										having count > 1")

	puts "Patients with duplicate ARV Encounters >>>>>>>> #{all_patients.count}"

	(all_patients || []).each do |pat|

		encounters = Encounter.find_by_sql("Select e.* from #{source_db}.encounter e
		                                      inner join #{source_db}.obs o on e.encounter_id = o.encounter_id
		                                    where e.patient_id = #{pat.patient_id}
		                                    and o.voided = 0
		                                    and e.date_created = (select max(date_created) 
		                                                          from #{source_db}.encounter 
		                                                          where encounter_type = e.encounter_type
		                                                          and patient_id = e.patient_id)
		                                    group by e.encounter_id")


		(encounters || []).each do |enc|
			equivalent_encounter = Encounter.find(enc.encounter_id) rescue nil

			if equivalent_encounter.blank?

#get the encounter on this day that originates from arv_visit
				visit_encounter = Encounter.find_by_sql("SELECT e.encounter_id from #{target_db}.encounter e
															INNER JOIN #{source_db}.encounter se on e.encounter_id = se.encounter_id AND
																se.encounter_type = #{art_visit_encounter_type}
									   WHERE DATE(e.encounter_datetime) = '#{enc.encounter_datetime}' AND
									    e.encounter_type = #{hiv_clinic_encounter_type}")
=begin
				encounter_to_update = Encounter.find(visit_encounter.first.encounter_id)

				#Update the encounter with the right items
				bart1_obs = Encounter.find_by_sql("SELECT * FROM #{source_db}.obs WHERE encounter_id = #{enc.encounter_id} ")
=end
				encounters_to_void << visit_encounter.first.encounter_id rescue nil
        to_void << visit_encounter.first.encounter_id rescue nil
				encounters_to_import << enc.encounter_id
        to_import << enc.encounter_id
#				puts "#{enc.encounter_id}"
			end
				
		end
	end
	puts ">>>>> Encounters to be voided >>>>>>>>>>>"
	puts "#{encounters_to_void}"
	puts "<<<<<< End of encounters to be voided <<<<<<<<<"
	
	puts ">>>>> Encounters to be imported >>>>>>>>>>>"
	puts "#{encounters_to_import.join(', ')}"
	puts "<<<<<< End of Encounters to be imported <<<<<<<<<"

end

start
