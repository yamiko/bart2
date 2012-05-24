query = " SELECT b2o.order_id
          FROM bart1.orders b1o LEFT JOIN bart1.encounter b1e ON b1e.encounter_id = b1o.encounter_id
                  LEFT JOIN bart2.encounter b2e ON b2e.encounter_type = 25
                              AND b1e.patient_id = b2e.patient_id AND b1e.encounter_type = 3
                              AND b1e.encounter_datetime = b2e.encounter_datetime

                  LEFT JOIN bart1.drug_order d ON b1o.order_id = d.order_id

                  LEFT JOIN bart2.orders b2o ON b2o.encounter_id = b2e.encounter_id
                  LEFT JOIN bart2.drug_order b2d ON b2d.order_id = b2o.order_id
                  LEFT JOIN bart2.bart1_to_bart2_drug_map bbm ON     b2d.drug_inventory_id = bbm.bart2_id
                  LEFT JOIN bart2.bart1_to_bart2_drug_map bbm2 ON d.drug_inventory_id = bbm2.bart1_id
          WHERE bbm.bart1_id = bbm2.bart1_id AND b1e.encounter_type = 3 
              AND b1o.voided = 1
              AND b2d.drug_inventory_id IS NOT NULL AND b2e.voided=0"

orders_array = Order.find_by_sql(query)

orders_array.each do |order_id|
  order = Order.find(state_id[:order_id])
  order.void
end
