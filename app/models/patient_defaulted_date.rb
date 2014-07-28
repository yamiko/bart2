class PatientDefaultedDate < ActiveRecord::Base
  set_table_name :patient_defaulted_dates
  belongs_to :patient

  def self.reset
ActiveRecord::Base.connection.execute <<EOF
    DELETE FROM patient_defaulted_dates;
EOF

    patients = Patient.find_by_sql("SELECT patient_id FROM earliest_start_date limit 20")

    patients.each do |patient|
      puts ">>>>>>>> working on patient_id: #{patient.patient_id} >>>>>>>>>>"
ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_defaulted_dates (patient_id, order_id, drug_id, equivalent_daily_dose, amount_dispensed, pills_remaining, start_date, end_date, defaulted_date)
select 
    o.person_id,
    o.order_id,
    ad.drug_inventory_id,
    ad.equivalent_daily_dose,
    IFNULL(o.value_numeric, o.value_text) as amount_dispensed,
    IFNULL(p.value_numeric, p.value_text) as pill_count,
    ord.start_date,
    ADDDATE(ord.start_date,
        (IFNULL(IFNULL(o.value_numeric, o.value_text), 0) + IFNULL(IFNULL(p.value_numeric, p.value_text), 0)) / ad.equivalent_daily_dose) as end_date,
ADDDATE(ADDDATE(ord.start_date,
        (IFNULL(IFNULL(o.value_numeric, o.value_text), 0) + IFNULL(IFNULL(p.value_numeric, p.value_text), 0)) / ad.equivalent_daily_dose), 56) as defaulted_date
from
    obs o
        inner join
    orders ord ON ord.order_id = o.order_id
        inner join
    drug_order ad ON ord.order_id = ad.order_id
        inner join
    arv_drug av ON av.drug_id = ad.drug_inventory_id
        left join
    (select 
        ob.person_id,
            ob.encounter_id,
            ob.order_id,
            ob.obs_datetime,
            ob.value_numeric,
            ob.value_text
    from
        obs ob
    inner join orders ord ON ord.order_id = ob.order_id
    inner join drug_order ad ON ord.order_id = ad.order_id
    inner join arv_drug av ON av.drug_id = ad.drug_inventory_id
    where ob.person_id = #{patient.patient_id}
        AND ob.concept_id = 2540
            and ob.voided = 0) as p ON p.person_id = o.person_id
        and p.order_id = o.order_id
where o.person_id = #{patient.patient_id}
        AND o.concept_id = 2834
        and o.voided = 0
order by o.order_id;
EOF
    end
  end
end
