def generate_ids
	persons = Person.find_by_sql("
		SELECT bart1_first_visit.patient_id
		FROM (
			SELECT DISTINCT a.patient_id
			FROM bart1.patient a
				LEFT JOIN bart2.patient b ON a.patient_id = b.patient_id AND
					a.voided=0 AND b.voided = 0
				LEFT JOIN bart1.encounter e1 ON e1.patient_id = a.patient_id
			WHERE e1.encounter_type = 1 
			)
			AS bart1_first_visit
			LEFT JOIN (
			SELECT DISTINCT a.patient_id
			FROM bart1.patient a
				LEFT JOIN bart2.patient b ON a.patient_id = b.patient_id AND
					a.voided=0 AND b.voided = 0
				LEFT JOIN bart2.encounter e2 ON e2.patient_id = a.patient_id
					AND e2.voided=0
			WHERE e2.encounter_type = 53
			)
			AS bart2_hiv_clinic_registration
			ON bart2_hiv_clinic_registration.patient_id = bart1_first_visit.patient_id
		WHERE bart2_hiv_clinic_registration.patient_id IS NULL	
	")
end
