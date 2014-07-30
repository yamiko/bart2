class PatientDefaultedDate < ActiveRecord::Base
  set_table_name :patient_defaulted_dates
  belongs_to :patient

  def self.reset
ActiveRecord::Base.connection.execute <<EOF
    DELETE FROM patient_defaulted_dates;
EOF

ActiveRecord::Base.connection.execute <<EOF
    DELETE FROM patient_max_defaulted_dates;
EOF

    start_time = Time.now.to_s
    patients = Patient.find_by_sql("SELECT patient_id FROM earliest_start_date WHERE patient_id IN (2993, 4215, 4346, 4598,438, 1248, 1609, 2353, 2439, 3273, 3361, 3700, 4463, 5115, 5119, 5902, 6062, 6487, 6578, 6724, 6941, 7118, 7855, 7874, 7973, 8296, 8420)")

    patients.each do |patient|
      puts ">>>>>>>> working on patient_id: #{patient.patient_id} >>>>>>>>>>"
ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_defaulted_dates (patient_id, order_id, drug_id, equivalent_daily_dose, amount_dispensed, quantity_given, start_date, end_date, defaulted_date)
SELECT 
    o.person_id,
    o.order_id,
    ad.drug_inventory_id,
    ad.equivalent_daily_dose,
    SUM(IFNULL(o.value_numeric, o.value_text)) as amount_dispensed,
    ad.quantity,
    ord.start_date,
    ADDDATE(ord.start_date,
        (IFNULL(ad.quantity, 0) / IFNULL(ad.equivalent_daily_dose, 2))) as end_date,
    ADDDATE(ADDDATE(ord.start_date,
            IFNULL((IFNULL(ad.quantity, 0) / IFNULL(ad.equivalent_daily_dose, 2)),
                    28)),
        56) AS defaulted_date
FROM
    obs o
        INNER JOIN
    orders ord ON ord.order_id = o.order_id
        INNER JOIN
    drug_order ad ON ord.order_id = ad.order_id
        INNER JOIN
    arv_drug av ON av.drug_id = ad.drug_inventory_id
WHERE
    o.person_id = #{patient.patient_id}
        AND o.concept_id = 2834
        AND o.voided = 0
GROUP BY o.order_id, ad.drug_inventory_id;
EOF
    end
    end_time = Time.now.to_s
    puts ">>>>>> total_patients: #{patients.length}"
    puts ">>>>>> started_at: #{start_time}"
    puts ">>>>>> finished_at: #{end_time}"
  end
end
