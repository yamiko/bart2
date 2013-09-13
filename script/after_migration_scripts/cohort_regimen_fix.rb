=begin

Creator : Precious Ulemu Bondwe
Date    : 2013-08-28 
Purpose : To swap quantity dispensed for all patients that had two dispensations
          at one visit. This problem was fixed in the import scripts.
=end



def start
    give_drugs_encounters = Patient.find_by_sql("SELECT patient_id, encounter_datetime,pres_drug_name2, dispensed_drug_name1, dispensed_quantity1, dispensed_quantity2, dm.new_drug_id
  FROM bart1_intermediate_bare_bones.give_drugs_encounters gde
	  LEFT OUTER JOIN drug_map dm ON dm.bart_one_name = gde.pres_drug_name2
  WHERE pres_drug_name2 = dispensed_drug_name1
  AND dispensed_quantity1 <> dispensed_quantity2")

  give_drugs_encounters.each do |patient| 
     ActiveRecord::Base.connection.execute <<EOF
UPDATE area_25_test_bart2_database.obs
SET value_numeric = #{patient.dispensed_quantity1}
WHERE value_drug = #{patient.new_drug_id}
AND person_id = #{patient.patient_id}
AND concept_id = 2834
AND obs_datetime = '#{patient.encounter_datetime}'
AND value_numeric <> #{patient.dispensed_quantity1}
EOF

query2 =<<EOF
SELECT order_id FROM obs 
WHERE value_drug = #{patient.new_drug_id} 
AND person_id = #{patient.patient_id} 
AND concept_id = 2834 
AND obs_datetime = '#{patient.encounter_datetime}'  
EOF

order_id = Patient.find_by_sql(query2).first.order_id
#raise order_id.to_yaml

     ActiveRecord::Base.connection.execute <<EOF
UPDATE area_25_test_bart2_database.drug_order
  SET quantity = #{patient.dispensed_quantity1}
  WHERE order_id = #{order_id}
  AND quantity <> #{patient.dispensed_quantity1}
EOF

  end
  
end

start
