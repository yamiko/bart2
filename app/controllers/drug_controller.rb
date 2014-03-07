class DrugController < GenericDrugController
  def art_summary_dispensation
    drug_name = params[:drug_name] rescue ''
    dispensation_date = params[:date] rescue "2014-01-06".to_date
    connection = ActiveRecord::Base.connection

    drug_order = connection.select_one("SELECT * FROM order_type WHERE 
      name='Drug Order' LIMIT 1")
    drug_order_type_id = drug_order["order_type_id"]
    dispensing_encounter_type = connection.select_one("SELECT * FROM encounter_type WHERE
      name='DISPENSING' LIMIT 1")
    dispensing_encounter_type_id = dispensing_encounter_type["encounter_type_id"]
    treatment_encounter_type = connection.select_one("SELECT * FROM encounter_type WHERE
      name='TREATMENT' LIMIT 1")
    treatment_encounter_type_id = treatment_encounter_type["encounter_type_id"]
    amount_dispensed_concept = Concept.find_by_name('Amount dispensed').id

    dispensation_data = connection.select_all("SELECT SUM(obs.value_numeric) as Bottles, d.name as DrugName FROM encounter e INNER JOIN encounter_type et
        ON e.encounter_type = et.encounter_type_id INNER JOIN obs ON e.encounter_id=obs.encounter_id
        INNER JOIN orders o
        ON obs.order_id = o.order_id INNER JOIN drug_order do ON o.order_id = do.order_id
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{dispensing_encounter_type_id} AND
        o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{dispensation_date} 00:00:00\"
        AND e.encounter_datetime <= \"#{dispensation_date} 23:59:59\"
        AND obs.concept_id = #{amount_dispensed_concept}
        AND e.voided=0 GROUP BY d.name")

=begin
    prescription_data = connection.select_all("SELECT SUM(do.quantity)/60 as Bottles, d.name as DrugName FROM encounter e INNER JOIN encounter_type et
        ON e.encounter_type = et.encounter_type_id INNER JOIN orders o
        ON e.encounter_id = o.encounter_id INNER JOIN drug_order do ON o.order_id = do.order_id
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id} AND
        o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{dispensation_date} 00:00:00\"
        AND e.encounter_datetime <= \"#{dispensation_date} 23:59:59\"
        AND e.voided=0 GROUP BY d.name ORDER BY e.encounter_datetime DESC LIMIT 100")
=end

    prescription_data = connection.select_all("SELECT (ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose) as Bottles,
        d.name as DrugName FROM encounter e INNER JOIN encounter_type et
        ON e.encounter_type = et.encounter_type_id INNER JOIN orders o
        ON e.encounter_id = o.encounter_id INNER JOIN drug_order do ON o.order_id = do.order_id
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id} AND
        o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{dispensation_date} 00:00:00\"
        AND e.encounter_datetime <= \"#{dispensation_date} 23:59:59\"
        AND e.voided=0")

    dispensations = {}
    dispensation_data.each do |data|
      drug_name = data["DrugName"]
      bottles = data["Bottles"]
      dispensations[drug_name] = {}
      dispensations[drug_name]["bottles"] = bottles
    end

    prescribed_drugs = {}
    prescription_data.each do |prescription|
      prescribed_drug = prescription["DrugName"]
      bottles = prescription["Bottles"].to_i
      prescribed_drugs[prescribed_drug] = 0 if prescribed_drugs[prescribed_drug].blank?
      prescribed_drugs[prescribed_drug]+=bottles
    end
    
    prescriptions = {}
    prescribed_drugs.each do |data|
      drug_name = data[0]
      bottles = data[1]
      prescriptions[drug_name] = {}
      prescriptions[drug_name]["bottles"] = bottles
    end
    stocks = {}

    arv_concepts = MedicationService.arv_drugs.map(&:concept_id)
    arv_drugs = Drug.find(:all, :conditions => ["concept_id IN (?)", arv_concepts])
    arv_drugs.each do |drug|
      stocks[drug.name] = Pharmacy.current_stock(drug.drug_id)
    end
=begin
    Regimen.find_by_sql(
      "select distinct(d.name), d.drug_id from regimen r
        inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
        inner join drug d on d.drug_id = rd.drug_inventory_id
        where r.regimen_index is not null
        and r.regimen_index != 0
      ").each do |drug| 
      stocks[drug.name] = Pharmacy.current_stock(drug.drug_id)  
    end
=end
    drug_summary = {}
    drug_summary["dispensations"] =  dispensations
    drug_summary["prescriptions"] = prescriptions
    drug_summary["stock_level"] = stocks

    render :text => drug_summary.to_json and return
    
  end
end
