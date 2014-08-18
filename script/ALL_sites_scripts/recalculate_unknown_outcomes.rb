# this script updates patient's reason for elibility if the patient have 'Unknown'
# reason for starting
#
  User.current = User.find(1)
   
  YesConcept = ConceptName.find_by_name('Yes')
  UnknownConcept = ConceptName.find_by_name('Unknown')
  NoneConcept = ConceptName.find_by_name('None')
  ReasonForStartingConcept = ConceptName.find_by_name('Reason for ART eligibility')
  CD4Count500 = ConceptName.find_by_name('CD4 COUNT LESS THAN OR EQUAL TO 500')
  CD4Count350 = ConceptName.find_by_name('CD4 COUNT LESS THAN OR EQUAL TO 350')
  CD4Count250 = ConceptName.find_by_name('CD4 COUNT LESS THAN OR EQUAL TO 250')
  CD4CountConcept = ConceptName.find_by_name('CD4 count')

  def start

    records = Observation.find(:all,:conditions =>["obs.encounter_id IN(SELECT o.encounter_id FROM obs o WHERE
      o.concept_id = ? AND o.value_coded = ? AND o.voided = 0)",ReasonForStartingConcept.concept_id,NoneConcept.concept_id],
      :joins => "INNER JOIN person p ON p.person_id = obs.person_id
      INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
      AND e.encounter_datetime = (SELECT MAX(i.encounter_datetime) FROM encounter i
      WHERE i.encounter_type = 52 AND i.patient_id = e.patient_id)", :select => "obs.*, p.*")

    records2 = Observation.find(:all,:conditions =>["obs.encounter_id IN(SELECT o.encounter_id FROM obs o WHERE
      o.concept_id = ? AND o.value_coded = ? AND o.voided = 0)",ReasonForStartingConcept.concept_id,UnknownConcept.concept_id],
      :joins => "INNER JOIN person p ON p.person_id = obs.person_id
      INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
      AND e.encounter_datetime = (SELECT MAX(i.encounter_datetime) FROM encounter i
      WHERE i.encounter_type = 52 AND i.patient_id = e.patient_id)", :select => "obs.*, p.*")

    records3 = Observation.find(:all,:conditions =>["obs.encounter_id IN(SELECT o.encounter_id FROM obs o WHERE
      o.concept_id = ? AND o.value_coded IS NULL AND o.voided = 0)",ReasonForStartingConcept.concept_id],
      :joins => "INNER JOIN person p ON p.person_id = obs.person_id
      INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
      AND e.encounter_datetime = (SELECT MAX(i.encounter_datetime) FROM encounter i
      WHERE i.encounter_type = 52 AND i.patient_id = e.patient_id)", :select => "obs.*, p.*")

    records = records + records2 + records3 #+ records4 + records5

    patient_obs = {}
    (records || []).each do |rec|
      if patient_obs[rec.person_id].blank?
        patient_obs[rec.person_id] = {:age_when_staged => patient_age(rec.birthdate, rec.birthdate_estimated, rec.date_created, rec.obs_datetime),
          :encounter_id => rec.encounter_id, :observations => [],:cd4_count => [], :reason_for_starting => nil,
          :obs_datetime => rec.obs_datetime
        }
      end
      if not rec.concept_id == CD4CountConcept.concept_id
        patient_obs[rec.person_id][:observations] << [rec.concept_id, rec.value_coded]
      else
        patient_obs[rec.person_id][:cd4_count] = [rec.value_modifier, rec.value_numeric]
      end
    end

    adult = conditions
    peds = conditions(14)

    (patient_obs || {}).each do |patient_id , att|
      adult_or_peds = (att[:age_when_staged] > 14) ? "ADULT" : "PEDS" rescue 'ADULT'
      if adult_or_peds == 'PEDS'
        who_stage = get_who_stage(att[:observations], peds, adult_or_peds)
      else
        who_stage = get_who_stage(att[:observations], adult, adult_or_peds)
      end

      att[:reason_for_starting] = who_stage unless who_stage.blank?

      if who_stage.blank? and att[:obs_datetime].to_date < '2011-07-01'.to_date
        if att[:cd4_count][0].blank? and att[:cd4_count][1] <= 250
          att[:reason_for_starting] = CD4Count250
        elsif att[:cd4_count][0] == '<' and att[:cd4_count][1] <= 250
          att[:reason_for_starting] = CD4Count250
        elsif att[:cd4_count][0] == '=' and att[:cd4_count][1] <= 250
          att[:reason_for_starting] = CD4Count250
        end
      end unless att[:cd4_count].blank?
      
      if who_stage.blank? and att[:obs_datetime].to_date >= '2011-07-01'.to_date
        if att[:cd4_count][0].blank? and att[:cd4_count][1] <= 350
          att[:reason_for_starting] = CD4Count350
        elsif att[:cd4_count][0] == '<' and att[:cd4_count][1] <= 350
          att[:reason_for_starting] = CD4Count350
        elsif att[:cd4_count][0] == '=' and att[:cd4_count][1] <= 350
          att[:reason_for_starting] = CD4Count350
        end
      end unless att[:cd4_count].blank?

      if who_stage.blank? and att[:obs_datetime].to_date >= '2014-04-01'.to_date
        if att[:cd4_count][0].blank? and att[:cd4_count][1] <= 500
          att[:reason_for_starting] = CD4Count500
        elsif att[:cd4_count][0] == '<' and att[:cd4_count][1] <= 500
          att[:reason_for_starting] = CD4Count500
        elsif att[:cd4_count][0] == '=' and att[:cd4_count][1] <= 500
          att[:reason_for_starting] = CD4Count500
        end
      end unless att[:cd4_count].blank?


    end
        
    (patient_obs || {}).each do |patient_id, att|
      next if att[:reason_for_starting].blank?
      encounter_id = att[:encounter_id]
      obs_datetime = att[:obs_datetime]
      cd4_count_modifier = att[:cd4_count][0]
      cd4_count = att[:cd4_count][1]
      reason_for_starting = att[:reason_for_starting]

      ActiveRecord::Base.connection.execute("UPDATE obs
        SET voided = 1, void_reason = 'Give a new reason for starting' 
        WHERE person_id = #{patient_id} AND encounter_id = #{encounter_id}
        AND voided = 0 AND concept_id = #{ReasonForStartingConcept.concept_id}")

      obs = Observation.new()
      obs.concept_id = ReasonForStartingConcept.concept_id
      obs.value_coded = reason_for_starting.concept_id
      obs.value_coded_name_id = reason_for_starting.id
      obs.encounter_id = encounter_id
      obs.obs_datetime = obs_datetime
      obs.person_id = patient_id
      obs.save

      puts "Patient ID: >>>>>>>>>>>> #{patient_id}"
      puts "Encounter ID: >>>>>>>>>>>> #{encounter_id}"
      puts "CD4 Count modifier: >>>>>>>>>>>> #{cd4_count_modifier}"
      puts "CD4 Count : >>>>>>>>>>>> #{cd4_count}"
      puts "Reason For Starting: >>>>>>>>>>>> #{reason_for_starting.name}"
      puts "......................................................................"

    end
            
  end

  def get_who_stage(observations, staging_concepts, patient_cat)
    return
    if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
      #in future we should do something here
      return
    else
      stage_iii = staging_concepts[2]
      stage_iv = staging_concepts[3]
    end

    stage = nil

    observations.each do |concept_id, value_coded|
      if stage_iii.include?(concept_id) and value_coded == YesConcept.concept_id
        stage = "WHO STAGE III " + patient_cat
        break
      end
    end

    observations.each do |concept_id, value_coded|
      if stage_iv.include?(concept_id) and value_coded == YesConcept.concept_id
        stage = "WHO STAGE III " + patient_cat
        break
      end
    end

    return if stage.blank?
    return ConceptName.find_by_name(stage)
  end

  def patient_age(birthdate, birthdate_estimated, date_created = Date.today, today = Date.today)
    return nil if birthdate.blank?
    birthdate = birthdate.to_date
    today = today.to_date
    date_created = date_created.to_date

    # This code which better accounts for leap years
    p_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate
    estimate = birthdate_estimated
    p_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0

  end

  def conditions(age = 15)
    if age > 14
      @who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I ADULT')
      @who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II ADULT')
      @who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III ADULT')
      @who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV ADULT')

      if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
        @not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked adult')
      end
    else
      @who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I PEDS')
      @who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II PEDS')
      @who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III PEDS')
      @who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV PEDS')
      if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
        @not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked peds')
      end
    end

    if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
      return [@who_stage_i, @who_stage_ii, @who_stage_iii, @who_stage_iv, @not_explicitly_asked]
    else
      return [@who_stage_i, @who_stage_ii, @who_stage_iii, @who_stage_iv]
    end
  end 

  def concept_set(concept_name)
    concept_id = ConceptName.find_by_name(concept_name).concept_id

    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.concept_id] }
    return options
  end
  
  start
