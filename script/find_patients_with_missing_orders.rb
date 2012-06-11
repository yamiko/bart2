def find

	Person.find_by_sql("
				SELECT DISTINCT p1
						FROM (
									SELECT  e1.patient_id AS p1, e2.patient_id AS p2, bbm.bart1_id,
													d1.drug_inventory_id, bbm.bart2_id, e2.encounter_datetime,
													SUM(IF(ISNULL(d1.quantity), 0, d1.quantity)) AS quantity_bart1,
													SUM(IF(ISNULL(d2.quantity), 0, d2.quantity)) AS quantity_bart2
											FROM mpc_bart1_data.encounter e1 LEFT JOIN 
													mpc_bart1_data.orders o1 ON o1.encounter_id=e1.encounter_id 
													LEFT JOIN mpc_bart1_data.drug_order d1 ON o1.order_id=d1.order_id
													LEFT JOIN mpc_bart2_data.encounter e2 ON e2.patient_id = e1.patient_id
															AND e2.encounter_datetime = e1.encounter_datetime
													LEFT JOIN mpc_bart2_data.bart1_to_bart2_drug_map bbm ON bbm.bart1_id = d1.drug_inventory_id
													LEFT JOIN mpc_bart2_data.orders o2 ON o2.encounter_id=e2.encounter_id
													LEFT JOIN mpc_bart2_data.drug_order d2 ON o2.order_id=d2.order_id
											WHERE e1.encounter_type = 3 AND e2.encounter_type = 25 AND o1.encounter_id IS NOT NULL
															AND e2.encounter_id IS NOT NULL AND bbm.bart2_id = d2.drug_inventory_id
											GROUP BY e1.patient_id, DATE(e1.encounter_datetime), bbm.bart1_id
											HAVING quantity_bart2!=quantity_bart1) AS missing
	")

end

print "\e[H\e[2J"

patients=find
f = File.open("/tmp/patients_id_with_missing_orders.DAT", 'w')

patients.each do |p|
	f.puts p.p1
	print "\r\r\r#{p.p1}"
end

f.close

puts "\r\rTotal Number of patients: #{patients.size}\n#{'/tmp/patients_id_with_missing_orders.DAT'}"
