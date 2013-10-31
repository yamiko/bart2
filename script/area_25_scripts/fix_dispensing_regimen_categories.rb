
$amount_dispensed = Concept.find_by_name("Amount Dispensed").concept_id
$weight = Concept.find_by_name("Weight (Kg)").concept_id

def start

  dispensing_type = EncounterType.find_by_name("Dispensing").id
  treatment_type = EncounterType.find_by_name("Treatment").id
  regimen_category_concept = Concept.find_by_name("Regimen Category").concept_id
  arv_drug_concepts =  MedicationService.arv_drugs.collect{|x| x.concept_id}

  arv_drugs = Drug.find(:all, :conditions => ["concept_id in (?)", arv_drug_concepts]).collect{|x| x.drug_id}

  dispensing_encounters = Encounter.find_by_sql("select * from encounter where encounter_id not in (
                                                    select e.encounter_id from encounter as e inner join
                                                    obs as o on e.encounter_id = o.encounter_id
                                                    where concept_id = #{regimen_category_concept}  and o.voided = 0
                                                    and encounter_type = #{dispensing_type})
                                                    and encounter_type = #{dispensing_type} AND voided = 0")

  count = dispensing_encounters.length

  (dispensing_encounters || []).each do |encounter|

    puts "Encounters to go : #{count}......Current Encounter ID: #{encounter.encounter_id}"
    dispensing_concepts = encounter.observations.collect{|x| x.concept_id}

    if !dispensing_concepts.include?(regimen_category_concept)

      date = encounter.encounter_datetime.to_date.strftime("%Y-%m-%d").to_s

      treat_reg_cat = Observation.find(:first, :conditions => ["concept_id = ? AND person_id = ? AND voided = ? AND obs_datetime >= ? AND obs_datetime <= ?",
                                        regimen_category_concept, encounter.patient_id, 0,(date + " 00:00:00"),(date + " 23:59:59") ])


      if treat_reg_cat.blank?
        puts "create new regimen"
        regimen_category = get_regimen_category(encounter, arv_drugs)

          if regimen_category != "Not Arvs"
            order_id = nil
            (encounter.observations || []).each do |obs|

              if obs.concept_id == $amount_dispensed
                order_id = obs.order_id
              end

            end


            reg_cat_obs = Observation.create({:concept_id => regimen_category_concept,
                                              :person_id => encounter.patient_id,
                                              :encounter_id => encounter.encounter_id,
                                              :value_text => regimen_category,
                                              :order_id => order_id,
                                              :obs_datetime => encounter.encounter_datetime
                                             })


          end
        else


          new_reg_category = Observation.new()
          new_reg_category.concept = treat_reg_cat.concept
          new_reg_category.person_id = treat_reg_cat.person_id
          new_reg_category.value_text = treat_reg_cat.value_text
          new_reg_category.order_id = treat_reg_cat.order_id
          new_reg_category.obs_datetime = treat_reg_cat.obs_datetime
          new_reg_category.encounter_id = encounter.encounter_id
          new_reg_category.creator = treat_reg_cat.creator
          new_reg_category.save

        end
      end




    count -= 1
  end

end


def get_regimen_category(encounter, arvs)

  drugs = []

  (encounter.observations || []).each do |obs|

    if obs.concept_id == $amount_dispensed

      drugs << obs.value_drug unless !arvs.include?(obs.value_drug)

    end

  end
  puts "Drugs dispensed #{drugs}"
  if drugs.blank?
    puts "not arv"
    return "Not Arvs"

  else

    weight_today = Observation.find(:first,
                                    :conditions => ["concept_id = ? AND person_id = ? AND voided = ? AND obs_datetime <= ?",
                                                    $weight, encounter.patient_id, 0,(date + " 23:59:59")],
                                    :order => "obs_datetime DESC" ).value_numeric rescue nil

    dispensed_drug_ids = drugs.collect{|x| Drug.find(x).concept_id}


    regimen_cat = Regimen.find_by_sql("SELECT regimen_index as regimen_cat  FROM regimen WHERE concept_id in (#{dispensed_drug_ids.join(',')})
  AND min_weight >= #{weight_today} AND max_weight <= #{weight_today} AND retired = 0") rescue []

    cats = regimen_cat.collect{|x| x.regimen_cat} rescue []

    if cats.uniq.length > 1
      return " "
    elsif cats.uniq.length == 0
       return " "
    elsif cats.uniq.length == 1
       return cats.first
    end

  end


end
start
