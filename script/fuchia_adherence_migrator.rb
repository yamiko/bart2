require 'mysql'

$mysql_conn = Mysql.new(ARGV[0], ARGV[1], ARGV[2],ARGV[3])

def start

  amount_brought_concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
  adherence_concept_id = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
  adherence_encounter_id = EncounterType.find_by_name("ART ADHERENCE").id
  dispense_concept_id = ConceptName.find_by_name("Amount dispensed").concept_id

  followups = $mysql_conn.query("SELECT * FROM tbfollowup WHERE  FdxReferenceProgram IN (167,168,169,379,380,381)
                                    AND FdnARVPill IS NOT NULL AND FdxReferencePatient > 1 ORDER BY FddVisit ASC")

  count = followups.num_rows
  puts "Number of records to be migrated: #{count}"

  followups.each do |follow_up|

    puts "#{count} encounters to go"
		patient = Patient.find(follow_up[3]) rescue nil 
		
		unless patient.blank?
		
    art_visit = Encounter.find(:first, :conditions => ['encounter_type = ? AND patient_id = ? and encounter_datetime =?',
                                                       EncounterType.find_by_name('hiv clinic consultation').id, follow_up[3],
                                                       follow_up[9]])

    last_dispense = Observation.find(:last,
                                     :conditions => ["concept_id =? AND person_id = ? AND obs_datetime < ? ",
                                                           dispense_concept_id, follow_up[3],follow_up[9]],
                                     :order => "obs_datetime DESC")

    if ( art_visit.blank? && last_dispense.blank? )

      Encounter.transaction do
        adherence_encounter = Encounter.new
        adherence_encounter.encounter_type = adherence_encounter_id
        adherence_encounter.patient_id = follow_up[3]
        adherence_encounter.encounter_datetime = follow_up[9]
        adherence_encounter.provider = Person.find(1)
        adherence_encounter.creator = 1
        if adherence_encounter.save
          obs = Observation.new()
          obs.concept_id = adherence_concept_id
          obs.encounter_id = adherence_encounter.id
          obs.person_id = adherence_encounter.patient_id
          obs.obs_datetime = adherence_encounter.encounter_datetime
          obs.value_text = follow_up[34]
					obs.creator = 1
          obs.save

        end
      end

    end
   end
   count -=1
  end

end

start
