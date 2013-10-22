
#Remember to write a function to get age for assigning of regimens

require 'mysql'

$mysql_conn = Mysql.new(ARGV[0], ARGV[1], ARGV[2],ARGV[3])
$cpt_drug_id = Drug.find_by_name('Cotrimoxazole (480mg tablet)').drug_id
$what_type_of_arv = Concept.find_by_name("What type of antiretroviral regimen")
$regimens_abstract = Concept.find_by_name("Arv regimens received abstracted construct")
$cpt_started = Concept.find_by_name('CPT started')
$regimen_category = Concept.find_by_name('Regimen Category')
$amount_dispensed = Concept.find_by_name('Amount Dispensed')
$yes_concept_id = ConceptName.find_by_name("Yes")
$location = Location.find(670)
$creator = User.find(1)

def init_variables
  #set Location first
  site_id = GlobalProperty.find_by_property('current_health_center_id').property_value

  location = Location.find(site_id)
  Location.current_location = location
end


def start

  init_variables
  patient_ids = Patient.all.collect{|x| x.id }
  fuchia_patients = $mysql_conn.query("SELECT FdxReference FROM tbpatient WHERE FdxReference IN (#{patient_ids.join(",")})")

  fuchia_patients.each do |patient|
    puts "Working with patient #{patient}"

      visits = $mysql_conn.query("SELECT FdxReference, FddVisit, FddVisitNext FROM tbfollowup WHERE FdxReferencePatient = #{patient}
                                AND FdxReferenceProgram IN (167,168,169,379,380,381) ORDER BY FddVisit ASC")

      visits.each do |visit|

        dispensations =  get_dispensations(visit[0])

        if dispensations.num_rows > 0

          prescribed_drugs, prescription_encounter = get_prescribed_drugs(visit[1], patient)

          dispense_encounter = Encounter.find(:last,
                                              :conditions =>["encounter_type = ? AND encounter_datetime = ? AND patient_id = ?",
                                                             EncounterType.find_by_name("DISPENSING").id,visit[1], patient])

          dispensed_drugs = []
          dispensed_drug = []
          dispensed_regimen_cat = ""
          dispensations.each do |dispensation|

            #check age here and modify query accordingly
            drug = $mysql_conn.query("SELECT Drug_Id, dose, FdsLookupShort FROM drug_map WHERE FdxReference = #{dispensation}").fetch_row

            if !prescribed_drugs.include?drug[0].to_i
              dispensed_drugs << drug[0]
              dispensed_drug << [drug[0].to_i, drug[1]]
            end

            if "COTRI" != drug[2].to_s
              dispensed_regimen_cat = dispensed_regimen_cat + drug[2].to_s + "/"
            end

          end

          dispensed_regimen_cat = dispensed_regimen_cat.chop



          if !dispensed_drugs.blank?

            if !dispensed_regimen_cat.blank?
              puts dispensed_regimen_cat
              cat = $mysql_conn.query("SELECT regimen_category FROM regimen_mapping WHERE
                                      fuchia_combination = '#{dispensed_regimen_cat}'").fetch_row()

              group = getAgeGroup(patient, visit[1])
              if cat != "Unknown"
                dispensed_regimen_cat = cat.to_s + group
              else
                dispensed_regimen_cat = cat.to_s
              end

            end
            puts "Create new orders"
            puts "Regimen category #{dispensed_regimen_cat}"

            create_order(dispensed_drug, prescription_encounter,visit[1], visit[2],patient[0], dispensed_regimen_cat, dispense_encounter)

          end



        end

      end

    end


end

def get_prescribed_drugs(date, patient)

  drug = []
  prescription = Encounter.find(:last,
                                :conditions =>["encounter_type = ? AND encounter_datetime = ? AND patient_id = ?",
                                               EncounterType.find_by_name("TREATMENT").id,date, patient])
  id = nil
  unless prescription.blank?

   id = prescription.id

    prescription.orders.each do |order|
      drug << order.drug_order.drug_inventory_id
    end

  end
  return [drug,id ]
end


def get_dispensations(id)

  dispensation = $mysql_conn.query("SELECT FdxReferenceDrug FROM tbfollowupdrug WHERE FdxReferenceFollowUp = #{id}")

  return dispensation

end

def create_order(fuchia_dispensations, pres_encounter_id, visit_date, next_date, patient_id, regimen_category, dispense_enc)


  #remember to check all observations created for treatment and dispensation encounters
  #remember to capture regimen categories
  if pres_encounter_id.nil?
     new_pres_enc = Encounter.create({:encounter_type => EncounterType.find_by_name("Treatment").id,
                                      :patient_id => patient_id,
                                      :provider_id => 1,
                                      :location_id => $location.id,
                                      :encounter_datetime => visit_date,
                                      :creator => 1
                                     })
     pres_encounter_id = new_pres_enc.id
  end

  if dispense_enc.blank?
      dispense_enc = Encounter.create({:encounter_type => EncounterType.find_by_name("Dispensing").id,
                                         :patient_id => patient_id,
                                         :provider_id => 1,
                                         :location_id => $location.id,
                                         :encounter_datetime => visit_date,
                                         :creator => 1
                                        })
  end

  puts "Creating for Patient:#{patient_id}.....Prescription Encounter:#{pres_encounter_id}......Despensation:#{dispense_enc.id}"
  if !pres_encounter_id.blank?

    Encounter.transaction do

      cpt_dispensed = false
      arv_dispensed = false

      fuchia_dispensations.each do |drug_id|
        drug = Drug.find(drug_id[0])
        duration = (next_date.to_date - visit_date.to_date).to_i rescue 30
        amount = drug_id[1].to_i * duration
        order = Order.new()
        order.patient_id = patient_id.to_i
        order.encounter_id = pres_encounter_id
        order.order_type = OrderType.find(1)
        order.concept_id =  drug.concept_id
        order.orderer = 1
        order.start_date = visit_date
        order.auto_expire_date = next_date
        order.creator = 1
        if order.save
          drug_order = DrugOrder.new
          drug_order.order_id = order.id
          drug_order.drug_inventory_id = drug_id[0]
          drug_order.dose = drug.dose_strength
          drug_order.equivalent_daily_dose = drug_id[1]
          drug_order.save
        end

        if ((drug.drug_id == $cpt_drug_id) && (!cpt_dispensed))
          Observation.create({:person_id => patient_id,
                              :concept_id => $cpt_started.id,
                              :value_coded => $yes_concept_id.concept_id,
                              :value_coded_name_id => $yes_concept_id.concept_name_id,
                              :encounter_id => pres_encounter_id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator
                             })
        else
          puts "Creating observation for #{drug.name} ON #{visit_date}"
          Observation.create({:person_id => patient_id,
                              :concept_id => $what_type_of_arv.id,
                              :value_coded => drug.concept_id,
                              :encounter_id => pres_encounter_id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator
                             })
          puts "Create regimens abstract observation"
          Observation.create({:person_id => patient_id,
                              :concept_id => $regimens_abstract.id,
                              :value_coded => drug.concept_id,
                              :encounter_id => dispense_enc.id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator
                             })

          arv_dispensed = true
        end

        puts "create amount dispensed observation ......amount: #{amount}"
        Observation.create({:person_id => patient_id,
                            :concept_id => $amount_dispensed.id,
                            :value_numeric => amount,
                            :value_drug => drug.drug_id,
                            :encounter_id => dispense_enc.id,
                            :obs_datetime => visit_date,
                            :location_id => $location.id,
                            :creator => $creator })

      end

      if (arv_dispensed)
        puts "Creating Regimen Category Observation"
        regimen_cat_obs = Observation.find(:first, :conditions => ["encounter_id = ? AND concept_id = ?", pres_encounter_id, $regimen_category.id])
        regimen_cat_obs2 = Observation.find(:first, :conditions => ["encounter_id = ? AND concept_id = ?", dispense_enc.id, $regimen_category.id])
        if (regimen_cat_obs.blank? && regimen_cat_obs2.blank? && regimen_category != "Unknown")
          Observation.create({:person_id => patient_id,
                              :concept_id => $regimen_category.id,
                              :value_text => regimen_category,
                              :encounter_id => pres_encounter_id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator
                             })
          puts "Creating Regimen Category Observation for dispensation"
          Observation.create({:person_id => patient_id,
                              :concept_id => $regimen_category.id,
                              :value_text => regimen_category,
                              :encounter_id => dispense_enc.id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator })

        elsif (regimen_cat_obs.blank? && !regimen_cat_obs2.blank? && regimen_category != "Unknown")

          puts "Creating Regimen Category Observation for prescription and updating dispensation"
          Observation.create({:person_id => patient_id,
                              :concept_id => $regimen_category.id,
                              :value_text => regimen_category,
                              :encounter_id => pres_encounter_id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator
                             })
          regimen_cat_obs2.update_attributes({:value_text => regimen_category})

        elsif (!regimen_cat_obs.blank? && regimen_cat_obs2.blank? && regimen_category != "Unknown")
          puts "Creating Regimen Category Observation for dispensation and updating precription"
          Observation.create({:person_id => patient_id,
                              :concept_id => $regimen_category.id,
                              :value_text => regimen_category,
                              :encounter_id => dispense_enc.id,
                              :obs_datetime => visit_date,
                              :location_id => $location.id,
                              :creator => $creator
                             })
          regimen_cat_obs.update_attributes({:value_text => regimen_category})

        elsif(regimen_category != "Unknown" && !regimen_cat_obs.blank? && !regimen_cat_obs2.blank?)
          puts "updating both"
          regimen_cat_obs.update_attributes({:value_text => regimen_category})
          regimen_cat_obs2.update_attributes({:value_text => regimen_category})

        elsif(regimen_category == "Unknown" && !regimen_cat_obs.blank? && !regimen_cat_obs2.blank?)
          puts "voiding both"
          regimen_cat_obs.update_attributes({:voided => 1, :voided_by => $creator, :date_voided => DateTime.now, :void_reason => "Migration error"})
          regimen_cat_obs2.update_attributes({:voided => 1, :voided_by => $creator, :date_voided => DateTime.now, :void_reason => "Migration error"})

        elsif (regimen_category == "Unknown" && !regimen_cat_obs.blank? && regimen_cat_obs2.blank?)
          puts "voiding for dispensation"
          regimen_cat_obs2.update_attributes({:voided => 1, :voided_by => $creator, :date_voided => DateTime.now, :void_reason => "Migration error"})

        elsif(regimen_category == "Unknown" && regimen_cat_obs.blank? && !regimen_cat_obs2.blank?)
          puts "voiding for prescription"
          regimen_cat_obs.update_attributes({:voided => 1, :voided_by => $creator, :date_voided => DateTime.now, :void_reason => "Migration error"})

        end

    end

  end
 end
end


def getAgeGroup(patient_id, visit_date)



    dob =  Person.find(:first, :conditions => ["person_id = ? ",patient_id]).birthdate.year
    present =  visit_date.to_date.year

    age = present - dob

    if age < 14
      return "P"
    else
      return "A"
    end

end

start
