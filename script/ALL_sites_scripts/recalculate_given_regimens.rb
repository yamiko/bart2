#Adding regimen category observation to all dispensing encounter

  User.current = User.find(1)
   
  DispensionEncounter = EncounterType.find_by_name('Dispensing')
  RegimensReceived = ConceptName.find_by_name('ARV regimens received abstracted construct')
  RegimenCategory = ConceptName.find_by_name('Regimen Category')

  def delete_all
    encounter_ids = Encounter.find(:all, :conditions => ["encounter_type=?",DispensionEncounter.id]).map(&:id)
    Observation.delete_all(["concept_id IN(?) AND encounter_id IN(?)", 
    [RegimensReceived.concept_id,RegimenCategory.concept_id], encounter_ids]) unless encounter_ids.blank?
  end

  def start

    delete_all

    start_datetime = Time.now()

    encounters = Encounter.find(:all,:conditions =>["encounter_datetime = (SELECT MAX(e.encounter_datetime)
      FROM encounter e WHERE e.patient_id = encounter.patient_id 
      AND encounter.encounter_id = e.encounter_id AND e.encounter_type = #{DispensionEncounter.id} 
      AND e.voided = 0)"],:group => "encounter.patient_id, encounter.encounter_datetime")

    (encounters || []).each_with_index do |encounter, i|
      regimen = set_received_regimen(encounter)
      unless regimen.blank?
        update_patient_regimen(encounter, regimen)
        puts "#################################################### #{(i+1)} of #{encounters.length}"
      end
    end

    puts ""
    puts ""
    puts ""
    puts "Started at: #{start_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "Ended at: #{Time.now().strftime('%Y-%m-%d %H:%M:%S')}"
  end



  def set_received_regimen(encounter)
    dispensed_drugs_inventory_ids = []
    start_date = encounter.encounter_datetime.strftime('%Y-%m-%d 00:00:00')
    end_date = encounter.encounter_datetime.strftime('%Y-%m-%d 23:59:59')
    patient_id = encounter.patient_id

    orders = Encounter.find(:first,:conditions =>["encounter_datetime = (SELECT MAX(e.encounter_datetime)
      FROM encounter e WHERE e.patient_id = ? AND e.encounter_datetime BETWEEN ? AND ? 
      AND e.encounter_type = #{DispensionEncounter.id} AND e.voided = 0)
      AND patient_id = ?",patient_id, start_date, end_date, patient_id]).observations.map{|obs| obs.order}.compact rescue []

    return if orders.blank?

    orders.each do | order |
      next if not MedicationService.arv(order.drug_order.drug)
      
      if order.drug_order.quantity and order.drug_order.quantity > 0
        dispensed_drugs_inventory_ids << order.drug_order.drug.id
      end
    end

    return if dispensed_drugs_inventory_ids.blank?

    if !dispensed_drugs_inventory_ids.blank?
      regimen_drug_order = ActiveRecord::Base.connection.select_all <<EOF
SELECT r.regimen_id, regimen_index, r.concept_id FROM regimen_drug_order x 
INNER JOIN regimen r ON r.regimen_id = x.regimen_id
WHERE x.drug_inventory_id IN (#{dispensed_drugs_inventory_ids.join(',')}) 
GROUP BY x.regimen_id 
HAVING count(x.drug_inventory_id) = #{dispensed_drugs_inventory_ids.length}
LIMIT 1
EOF

    end

    if not regimen_drug_order.first['regimen_id'].blank?
      return Regimen.find(regimen_drug_order.first['regimen_id'])
    end rescue nil
  end

  def update_patient_regimen(encounter, regimen)
    selected_regimen = regimen
    regimen_category_id = regimen.concept_id

    if encounter.observations.find_by_concept_id(RegimenCategory.concept_id).blank?
      puts ".............. Created Regimen Category: Encounter ID: #{encounter.id}"
      obs = Observation.create(
        :concept_name => "Regimen Category",
        :person_id => encounter.patient_id,
        :encounter_id => encounter.id,
        :value_text => selected_regimen.regimen_index,
        :obs_datetime => encounter.encounter_datetime) if !selected_regimen.blank?
    end

    if encounter.observations.find_by_concept_id(RegimensReceived.concept_id).blank?
      puts ">>>>>>>>>>>>>> Created ARV regimens received abstracted construct: Encounter ID: #{encounter.id}"
      obs = Observation.new(
        :concept_name => "ARV regimens received abstracted construct",
        :person_id => encounter.patient_id,
        :encounter_id => encounter.id,
        :value_coded => regimen.concept_id,
        :obs_datetime => encounter.encounter_datetime)

      obs.save
    end

  end

 start
