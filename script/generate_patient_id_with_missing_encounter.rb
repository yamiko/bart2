
@bart1_encounter_type = ARVG[0]
@bart2_encounter_type = ARVG[1]


def generate_ids
	missing_ids = Patient.find_by_sql("
		SELECT bart1_first_visit.patient_id
		FROM (
			SELECT DISTINCT a.patient_id
			FROM bart1.patient a
				LEFT JOIN bart2.patient b ON a.patient_id = b.patient_id AND
					a.voided=0 AND b.voided = 0
				LEFT JOIN bart1.encounter e1 ON e1.patient_id = a.patient_id
				LEFT JOIN bart1.obs o1 ON e1.encounter_id = o1.encounter_id
            AND o1.voided = 0
			WHERE e1.encounter_type = #{@bart1_encounter_type}
			)
			AS bart1_first_visit
			LEFT JOIN (
			SELECT DISTINCT a.patient_id
			FROM bart1.patient a
				LEFT JOIN bart2.patient b ON a.patient_id = b.patient_id AND
					a.voided=0 AND b.voided = 0
				LEFT JOIN bart2.encounter e2 ON e2.patient_id = a.patient_id
					AND e2.voided=0
				LEFT JOIN bart2.obs o2 ON e2.encounter_id = o2.encounter_id
                                        AND o2.voided = 0
			WHERE e2.encounter_type = #{@bart2_encounter_type}
			)
			AS bart2_hiv_clinic_registration
			ON bart2_hiv_clinic_registration.patient_id = bart1_first_visit.patient_id
		WHERE bart2_hiv_clinic_registration.patient_id IS NULL	
	")

	File.open('/tmp/patient_ids.txt', 'w') do |f|
		missing_ids.each do |patient|
			f.puts patient.patient_id
			puts patient.patient_id
		end
	end

	puts "*************************************"

	puts "#{missing_ids.size} patient id found!"
	puts "File location: /tmp/patient_ids.txt"

	puts "*************************************"

	puts "Successful"
end

generate_ids
