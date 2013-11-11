
def replace_encounters
    dispensing_encounter_id = EncounterType.find_by_name("DISPENSING").id
    regimen_category = ConceptName.find_by_name("REGIMEN CATEGORY").concept_id
    treatment_encounter_id = EncounterType.find_by_name("TREATMENT").id
    program_id = Program.find_by_name('HIV PROGRAM').id

    Encounter.find_by_sql("
                  SELECT * FROM obs o
                  INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                  WHERE e.encounter_type = #{treatment_encounter_id}
                  AND o.concept_id = #{regimen_category}
                  AND o.voided = 0").each{|prescription|
                  dates = prescription.obs_datetime.to_date
                  category = prescription.value_text
                  person_id = prescription.person_id

                  if ! category.blank?
                      obs = Encounter.find_by_sql("
                                            SELECT * FROM obs o
                                            INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                                            WHERE e.encounter_type = #{dispensing_encounter_id}
                                            AND o.concept_id = #{regimen_category}
                                            AND DATE(o.obs_datetime) = '#{dates}'
                                            AND o.person_id = #{person_id}
                                            AND o.voided = 0")
                      if obs.blank?
                          dispensed = Encounter.find_by_sql("
                                            SELECT * FROM obs o
                                            INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                                            WHERE e.encounter_type = #{dispensing_encounter_id}
                                            AND DATE(o.obs_datetime) = '#{dates}'
                                            AND o.person_id = #{person_id}
                                            AND o.voided = 0").first rescue []
                            if ! dispensed.blank?

                               obs = Observation.new()
                               obs.obs_datetime = dates
                               obs.concept_id = regimen_category
                               obs.encounter_id = dispensed.encounter_id
                               obs.value_text = category
                               obs.person_id = person_id
                               obs.creator = 1
                               if obs.save
                                  puts "Saving Patient ID : #{person_id} "
                               end
                            end
                                            
                      end
                  end

                  }



end

replace_encounters