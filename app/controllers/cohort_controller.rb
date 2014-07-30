
class CohortController < ActionController::Base

  @@first_registration_date = nil
  @@total_alive_and_on_art = nil
  @@start_date = nil
  @@end_date = nil
  @@regimens = nil
  @@children_join = " AND TRUNCATE(DATEDIFF(ftc.earliest_start_date, ftc.birthdate)/365, 3) >= 0 AND
      TRUNCATE(DATEDIFF(ftc.earliest_start_date, ftc.birthdate)/365, 0) <= 14"
  @@female_join = " AND ftc.gender REGEXP 'F' " 

  def initialize
	
		@@first_registration_date = FlatCohortTable.find(
		  :first,
		  :order => 'earliest_start_date ASC'
		).earliest_start_date.to_date rescue nil

	end

  def index

  end

  def select_date
  end

  def cohort 
   
    if params[:cohort_type] == "Survival Analysis"
     
      render :template => "/cohort/survival_analysis"
    end
  end

  def mastercard
  end

  def drill_down
    @patients = CohortPerson.find(:all, :conditions => ["person_id IN (?)",
        params[:field].split(",")]).collect{|p|
      [p.person_id, (p.names.first.given_name rescue "&nbsp;"),
        (p.names.first.family_name rescue "&nbsp;"), (p.birthdate rescue "&nbsp;"), p.gender]
    }
  end

  def current_site
    current_site = ""
    current_site = FlatCohortTable.find_by_sql("SELECT current_location
                                                FROM flat_cohort_table
                                                LIMIT 1").map(&:current_location).first

    render :text => current_site
  end

  def quarter(start_date=Time.now.strftime("%Y-%m-%d"), end_date=Time.now.strftime("%Y-%m-%d"), section=nil)
    startdate = Date.parse(start_date)
    enddate = Date.parse(end_date)

    retstr = ""

    if startdate.year == enddate.year
      if ((startdate.month - 1)/3) == ((enddate.month - 1)/3)
        q = ((startdate.month - 1)/3)

        case q.to_s
        when "0":
            retstr = startdate.year.to_s + " - 1<sup>st</sup> Quarter"
        when "1":
            retstr = startdate.year.to_s + " - 2<sup>nd</sup> Quarter"
        when "2":
            retstr = startdate.year.to_s + " - 3<sup>rd</sup> Quarter"
        when "3":
            retstr = startdate.year.to_s + " - 4<sup>th</sup> Quarter"
        end
      else
        retstr = startdate.strftime("%d/%b/%Y") + " to " + enddate.strftime("%d/%b/%Y")
      end
    else
      retstr = startdate.strftime("%d/%b/%Y") + " to " + enddate.strftime("%d/%b/%Y")
    end

    render :text => retstr
  end

  def art_defaulters#(start_date=Time.now, end_date=Time.now, section=nil)
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    @defaulters = []
  
    if @defaulters.blank?

      patients = FlatCohortTable.find_by_sql("SELECT patient_id
                                            FROM flat_cohort_table
                                            WHERE hiv_program_state = 'Defaulter'
                                            AND hiv_program_start_date <= '#{end_date}'
                                            AND current_state_for_program(patient_id, 1, '#{end_date}') NOT IN (6, 2, 3)").map(&:patient_id)

      @defaulters = patients
    else
      patients = @defaulters
    end

  end
 
  def total_alive_and_on_art(defaulted_patients)
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = []
    
    defaulters = 0
    
    defaulters = defaulted_patients.join(',') if !defaulted_patients.blank?

		if $total_alive_and_on_art.blank?

      patients = FlatCohortTable.find_by_sql("SELECT 
                                        fct.patient_id
                                    FROM
                                        flat_cohort_table fct
                                    WHERE
                                        fct.earliest_start_date <= '#{end_date}'
                                    AND 
                                       current_state_for_program(fct.patient_id, 1, '#{end_date}') = 7
                                    AND fct.patient_id NOT IN (#{defaulters})").map(&:patient_id)

			$total_alive_and_on_art = patients
		else
			patients = $total_alive_and_on_art
		end
   
  end

  # Start Cohort queries
  def defaulted(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients =  []

    @defaulters ||= art_defaulters#(start_date, end_date)

    value = @defaulters unless @defaulters.blank?
    render :text => value.to_json
  end
    
  def total_on_art(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    #patients =  []

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)
    
    patients = $total_alive_and_on_art

    value = patients unless patients.blank?

    render :text => value.to_json
  end
  
  def new_total_patients_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    art_defaulters = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = art_defaulters unless art_defaulters.blank?
  end

  def new_total_patients_reg_with_age(start_date=Time.now, end_date=Time.now, min_age = 0, max_age = nil)
    value = []

    condition = ""
    if !max_age.blank?
      condition = "AND TRUNCATE(DATEDIFF(ftc.earliest_start_date, ftc.birthdate)/365, 3) >= #{min_age} AND
      TRUNCATE(DATEDIFF(ftc.earliest_start_date, ftc.birthdate)/365, 0) <= #{max_age}"
    end
    
    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}' #{condition}
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    value
  end

  def cum_total_patients_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')        

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def new_total_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    value = []

    @total_patients_reg = new_total_patients_reg(start_date,end_date)
    @total_patients_reg = [] if @total_patients_reg.blank?

    @total_patients_reg.each do |patient|
      patients << patient
    end

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_total_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients =  []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    @total_patients_reg = cum_total_patients_reg(@@first_registration_date,end_date)
    @total_patients_reg = [] if @total_patients_reg.blank?

    @total_patients_reg.each do |patient|  
      patients << patient
    end

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_first_time(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ft1.patient_id, ft1.ever_registered_at_art_clinic
                FROM flat_table1 ft1
                INNER JOIN flat_cohort_table ftc on ftc.patient_id = ft1.patient_id
                WHERE (ft1.ever_registered_at_art_clinic = 'No' OR ft1.ever_registered_at_art_clinic IS NULL)
                AND ftc.earliest_start_date >= '#{start_date}'
                AND ftc.earliest_start_date <= '#{end_date}'
                GROUP BY ft1.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def cum_first_time(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')     

    patients = FlatTable1.find_by_sql("SELECT ft1.patient_id, ft1.ever_registered_at_art_clinic
                FROM flat_table1 ft1
                    INNER JOIN flat_cohort_table ftc on ftc.patient_id = ft1.patient_id and ftc.earliest_start_date <= '#{end_date}'
                WHERE (ft1.ever_registered_at_art_clinic = 'No' 
                       OR ft1.ever_registered_at_art_clinic IS NULL
                       OR ft1.ever_registered_at_art_clinic = 'Unknown')
                GROUP BY ft1.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def new_re_initiated(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients_with_date_art_taken_obs = []
    patients_with_taken_arvs_in_past_2months_no = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    first_time_pats = new_first_time(start_date, end_date)

    patients_with_date_art_taken_obs = FlatCohortTable.find_by_sql("SELECT 
                                                ftc.patient_id
                                            FROM
                                                flat_cohort_table ftc
                                                    LEFT OUTER JOIN
                                                flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ft1.ever_registered_at_art_clinic = 'Yes'
                                               AND (DATEDIFF(ft1.date_art_last_taken_v_date,
                                                        ft1.date_art_last_taken) > 14)
                                                    AND (ftc.earliest_start_date >= '#{start_date}'
                                                    AND ftc.earliest_start_date <= '#{end_date}')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    patient_ids = patients_with_date_art_taken_obs
    patient_ids = [0] if patient_ids.blank?

    patients_with_taken_arvs_in_past_2months_no = FlatCohortTable.find_by_sql("SELECT 
                                                        ftc.patient_id
                                                    FROM
                                                         flat_cohort_table ftc
                                                      LEFT OUTER JOIN
                                                         flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                                    WHERE (ft1.ever_registered_at_art_clinic = 'Yes'
                                                        AND ft1.taken_art_in_last_two_months = 'No')
                                                    AND (ftc.earliest_start_date >= '#{start_date}'
                                                        AND ftc.earliest_start_date <= '#{end_date}')
                                                    AND ftc.patient_id NOT IN (#{patient_ids.join(',')})
                                                    GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    patients = (patients_with_date_art_taken_obs + patients_with_taken_arvs_in_past_2months_no).uniq

    value = patients unless patients.blank?
  end

  def cum_re_initiated(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients_with_date_art_taken_obs = []
    patients_with_taken_arvs_in_past_2months_no = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    first_time_pats = cum_first_time(end_date)

    patients_with_date_art_taken_obs = FlatCohortTable.find_by_sql("SELECT 
                                                ftc.patient_id
                                            FROM
                                                flat_cohort_table ftc
                                                    LEFT OUTER JOIN
                                                flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ft1.ever_registered_at_art_clinic = 'Yes'
                                               AND (DATEDIFF(ft1.date_art_last_taken_v_date,
                                                        ft1.date_art_last_taken) > 14)
                                                    AND ftc.earliest_start_date <= '#{end_date}'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}


    patient_ids = patients_with_date_art_taken_obs
    patient_ids = [0] if patient_ids.blank?

    patients_with_taken_arvs_in_past_2months_no = FlatCohortTable.find_by_sql("SELECT 
                                                        ftc.patient_id
                                                    FROM
                                                         flat_cohort_table ftc
                                                      LEFT OUTER JOIN
                                                         flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                                    WHERE (ft1.ever_registered_at_art_clinic = 'Yes'
                                                        AND ft1.taken_art_in_last_two_months = 'No')
                                                    AND ftc.earliest_start_date <= '#{end_date}'
                                                    AND ftc.patient_id NOT IN (#{patient_ids.join(',')})
                                                    GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    patients = (patients_with_date_art_taken_obs + patients_with_taken_arvs_in_past_2months_no).uniq
    
    value = patients unless patients.blank?
  end

  def new_ft(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = new_first_time(start_date, end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_ft(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')     
    
    patients = cum_first_time(@@first_registration_date, end_date)
    
    value = patients unless patients.blank?
    
    render :text => value.to_json
  end

  def new_re(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    patients = new_re_initiated(start_date, end_date) rescue []
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_re(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    patients = cum_re_initiated(start_date, end_date)
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_ti(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    @newly_total_registered = new_total_patients_reg(start_date,end_date) rescue []
    @newly_first_time = new_first_time(start_date,end_date) rescue []
    @newly_re_initied = new_re_initiated(start_date,end_date) rescue []
                
    patients = (@newly_total_registered.to_a - (@newly_first_time.to_a + @newly_re_initied.to_a))

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_ti(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    @cum_total_registered = cum_total_patients_reg(@@first_registration_date,end_date)
    @cum_first_time = cum_first_time(@@first_registration_date,end_date)
    @cum_re_initied = cum_re_initiated(@@first_registration_date,end_date)

    patients = (@cum_total_registered.to_a - (@cum_first_time.to_a + @cum_re_initied.to_a))

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_males(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND ftc.gender = 'Male'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_males(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND ftc.gender = 'Male'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_patient_pregnant(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT 
                                      ft1.patient_id
                                  FROM
                                      flat_table1 ft1
                                          INNER join
                                      flat_cohort_table ftc ON ftc.patient_id = ft1.patient_id
                                          INNER JOIN
                                      encounter e ON e.encounter_id = ft1.pregnant_yes_enc_id
                                          and e.voided = 0
                                          AND e.encounter_type IN (52)
                                  WHERE
                                      (e.encounter_datetime >= '#{start_date}'
                                          AND e.encounter_datetime <= '#{end_date}')
                                          AND (ftc.earliest_start_date >= '#{start_date}'
                                          AND ftc.earliest_start_date <= '#{end_date}')
                                          AND DATEDIFF(ft1.pregnant_yes_v_date,
                                              ftc.earliest_start_date) <= 30
                                          AND DATEDIFF(ft1.pregnant_yes_v_date,
                                              ftc.earliest_start_date) > - 1
                                          AND ft1.pregnant_yes = 'Yes'
                                  GROUP BY ft1.patient_id
                                  UNION ALL
                                  SELECT 
                                      ft2.patient_id
                                  FROM
                                      flat_table2 ft2
                                          INNER join
                                      flat_table1 ftc ON ftc.patient_id = ft2.patient_id
                                          INNER JOIN
                                      encounter e ON e.encounter_id = ft2.pregnant_yes_enc_id
                                          and e.voided = 0
                                          AND e.encounter_type IN (53)
                                  WHERE
                                      (e.encounter_datetime >= '#{start_date}'
                                          AND e.encounter_datetime <= '#{end_date}')
                                          AND (ftc.earliest_start_date >= '#{start_date}'
                                          AND ftc.earliest_start_date <= '#{end_date}')
                                          AND DATEDIFF(ft2.visit_date,
                                              ftc.earliest_start_date) <= 30
                                          AND DATEDIFF(ft2.visit_date,
                                              ftc.earliest_start_date) > - 1
                                          AND ft2.pregnant_yes = 'Yes'
                                  GROUP BY ft2.patient_id").map(&:patient_id)

    value = patients.uniq unless patients.blank?
    value
  end

  def new_non_preg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    pregnant_women = new_patient_pregnant(start_date, end_date)

    all_women = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              WHERE ftc.earliest_start_date >= '#{start_date}'
                                              AND ftc.earliest_start_date <= '#{end_date}'
                                              AND ftc.gender = 'Female'
                                              GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    patients = (all_women || []) - (pregnant_women || [])

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_patient_pregnant(start_date, end_date=Time.now, section=nil)
    value = []
    patients = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT 
                                      ft1.patient_id
                                  FROM
                                      flat_table1 ft1
                                          INNER join
                                      flat_cohort_table ftc ON ftc.patient_id = ft1.patient_id
                                          INNER JOIN
                                      encounter e ON e.encounter_id = ft1.pregnant_yes_enc_id
                                          and e.voided = 0
                                          AND e.encounter_type IN (52)
                                  WHERE
                                      e.encounter_datetime <= '#{end_date}'
                                          AND ftc.earliest_start_date <= '#{end_date}'
                                          AND DATEDIFF(ft1.pregnant_yes_v_date,
                                              ftc.earliest_start_date) <= 30
                                          AND DATEDIFF(ft1.pregnant_yes_v_date,
                                              ftc.earliest_start_date) > - 1
                                          AND ft1.pregnant_yes = 'Yes'
                                  GROUP BY ft1.patient_id
                                  UNION ALL
                                  SELECT 
                                      ft2.patient_id
                                  FROM
                                      flat_table2 ft2
                                          INNER join
                                      flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                                          INNER JOIN
                                      encounter e ON e.encounter_id = ft2.pregnant_yes_enc_id
                                          and e.voided = 0
                                          AND e.encounter_type IN (53)
                                  WHERE
                                           e.encounter_datetime <= '#{end_date}'
                                          AND ftc.earliest_start_date <= '#{end_date}'
                                          AND DATEDIFF(ft2.visit_date,
                                              ftc.earliest_start_date) <= 30
                                          AND DATEDIFF(ft2.visit_date,
                                              ftc.earliest_start_date) > - 1
                                          AND ft2.pregnant_yes = 'Yes'
                                  GROUP BY ft2.patient_id").map(&:patient_id) 

    value = patients.uniq unless patients.blank?
  end

  def cum_non_preg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    all_women = []
    pregnant_women = []


    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    pregnant_women = cum_patient_pregnant(@@start_date, end_date)
    
    all_women = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              WHERE ftc.earliest_start_date <= '#{end_date}'
                                              AND ftc.gender = 'Female'
                                              GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    patients = (all_women || []) - (pregnant_women || [])

    value = patients unless patients.blank?

    render :text => value.to_json
  end

  def new_preg_all_age(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    all_women = []
    pregnant_women = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    pregnant_women = new_patient_pregnant(start_date, end_date)

    value = pregnant_women unless pregnant_women.blank?
    render :text => value.to_json
  end

  def cum_preg_all_age(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    pregnant_women = cum_patient_pregnant(@@start_date, end_date)
      
    value = pregnant_women unless pregnant_women.blank?
    render :text => value.to_json
  end

  def new_infants_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')                        
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id,ftc.earliest_start_date, ftc.age_at_initiation
                FROM flat_cohort_table ftc 
                WHERE ftc.earliest_start_date >= '#{start_date}' 
                AND ftc.earliest_start_date <= '#{end_date}'
                AND ftc.age_at_initiation >= 0
				        AND ftc.age_at_initiation < 2
                GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def cum_infants_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id,ftc.earliest_start_date, ftc.age_at_initiation
                FROM flat_cohort_table ftc 
                WHERE ftc.earliest_start_date <= '#{end_date}'
                AND ftc.age_at_initiation >= 0
				        AND ftc.age_at_initiation < 2
                GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def new_a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = new_infants_reg(start_date,end_date) 

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = cum_infants_reg(nil,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_children_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id,ftc.earliest_start_date, ftc.age_at_initiation
                FROM flat_cohort_table ftc 
                WHERE ftc.earliest_start_date >= '#{start_date}' 
                AND ftc.earliest_start_date <= '#{end_date}'
                AND ftc.age_at_initiation >= 2
				        AND ftc.age_at_initiation < 15
                GROUP BY ftc.patient_id").collect{|p| p.patient_id}
    value = patients unless patients.blank?
  end

  def cum_children_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id,ftc.earliest_start_date, ftc.age_at_initiation
                FROM flat_cohort_table ftc 
                WHERE ftc.earliest_start_date <= '#{end_date}'
                AND ftc.age_at_initiation >= 2
				        AND ftc.age_at_initiation < 15
                GROUP BY ftc.patient_id").collect{|p| p.patient_id}   

    value = patients unless patients.blank?
  end

  def new_b(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = new_children_reg(start_date,end_date) 

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_b(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = cum_children_reg(@@first_registration_date,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_adults_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id,ftc.earliest_start_date, ftc.age_at_initiation
                FROM flat_cohort_table ftc 
                WHERE ftc.earliest_start_date >= '#{start_date}' 
                AND ftc.earliest_start_date <= '#{end_date}'
                AND ftc.age_at_initiation >= 15
				        AND ftc.age_at_initiation < 1000
                GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def cum_adults_reg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id,ftc.earliest_start_date, ftc.age_at_initiation
                FROM flat_cohort_table ftc 
                WHERE ftc.earliest_start_date <= '#{end_date}'
                AND ftc.age_at_initiation >= 15
				        AND ftc.age_at_initiation < 1000
                GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def new_c(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = new_adults_reg(start_date,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_c(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = cum_adults_reg(@@first_registration_date,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_unk_age(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    @newly_total_registered = new_total_patients_reg(start_date,end_date)
    @newly_total_adults_registered = new_adults_reg(start_date,end_date)
    @newly_total_children_registered = new_children_reg(start_date,end_date)
    @newly_total_infants_registered = new_infants_reg(start_date,end_date)
    
    @newly_total_registered = [] if @newly_total_registered.blank?
    @newly_total_adults_registered = [] if @newly_total_adults_registered.blank?
    @newly_total_children_registered = [] if @newly_total_children_registered.blank?
    @newly_total_infants_registered = [] if @newly_total_infants_registered.blank?
    
    patients = (@newly_total_registered - (@newly_total_adults_registered + @newly_total_children_registered + @newly_total_infants_registered))
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_unk_age(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    
    @cum_total_registered = cum_total_patients_reg || []
    @cum_total_adults_registered = cum_adults_reg || []
    @cum_total_children_registered = cum_children_reg || []
    @cum_total_infants_registered = cum_infants_reg || []

    patients = (@cum_total_registered - (@cum_total_adults_registered + @cum_total_children_registered + @cum_total_infants_registered))
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_pres_hiv(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')                            
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%Presumed%'
                                                 OR ft1.who_stages_criteria_present LIKE '%Presumed%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_pres_hiv(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%Presumed%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_conf_hiv(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%Confirmed%'
                                                OR ft1.reason_for_eligibility LIKE '%HIV DNA%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_conf_hiv(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%Confirmed%'
                                                OR ft1.reason_for_eligibility LIKE '%HIV DNA%')
                                            OR (ft1.who_stages_criteria_present LIKE '%Confirmed%'
                                                OR ft1.who_stages_criteria_present LIKE '%HIV DNA%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_who_1_2(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%CD4 COUNT LESS%'
                                                OR ft1.reason_for_eligibility LIKE '%CD4 COUNT <=%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage II peds%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage I peds%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage II adult%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage I adult%'
                                                OR ft1.reason_for_eligibility LIKE '%Lymphocyte count below threshold%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_who_1_2(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%CD4 COUNT LESS%'
                                                OR ft1.reason_for_eligibility LIKE '%CD4 COUNT <=%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage II peds%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage I peds%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage II adult%'
                                                OR ft1.reason_for_eligibility LIKE '%WHO stage I adult%'
                                                OR ft1.reason_for_eligibility LIKE '%Lymphocyte count below threshold%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_who_2(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility = 'Lymphocyte count below threshold with who stage 2'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_who_2(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility = 'Lymphocyte count below threshold with who stage 2'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_children(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%HIV infected%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_children(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility LIKE '%HIV infected%')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_breastfeed(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility  = 'Currently breastfeeding child'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_breastfeed(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility  = 'Currently breastfeeding child'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_preg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility  = 'Patient pregnant'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_preg(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                                LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility  = 'Patient pregnant'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_who_3(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility  = 'WHO stage III adult'
                                                OR ft1.reason_for_eligibility = 'WHO stage III peds')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_who_3(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility  = 'WHO stage III adult'
                                                OR ft1.reason_for_eligibility = 'WHO stage III peds')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_who_4(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility  = 'WHO stage IV adult'
                                                OR ft1.reason_for_eligibility = 'WHO stage IV peds')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_who_4(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility  = 'WHO stage IV adult'
                                                OR ft1.reason_for_eligibility = 'WHO stage IV peds')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def new_other_reason(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility = 'Unknown'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_other_reason(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND ft1.reason_for_eligibility  = 'Unknown'
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  ######current episode of TB
  def new_total_current_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.pulmonary_tuberculosis = 'Yes' OR
                                                 ft1.extrapulmonary_tuberculosis = 'Yes' OR
                                                 ft1.who_stages_criteria_present IN ('Extrapulmonary tuberculosis (EPTB)', 'Pulmonary tuberculosis', 'Pulmonary tuberculosis (current)'))
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def cum_total_current_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                             LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.pulmonary_tuberculosis = 'Yes' OR
                                                 ft1.extrapulmonary_tuberculosis = 'Yes' OR
                                                 ft1.who_stages_criteria_present IN ('Extrapulmonary tuberculosis (EPTB)', 'Pulmonary tuberculosis', 'Pulmonary tuberculosis (current)'))
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end  

  def new_current_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = new_total_current_tb(start_date,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_current_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = cum_total_current_tb(@@first_registration_date, end_date)
 
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  ##########TB within the last two years
  def new_total_tb_w2yrs(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.pulmonary_tuberculosis_last_2_years = 'Yes' OR
                                                 ft1.who_stages_criteria_present = 'Tuberculosis (PTB or EPTB) within the last 2 years')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}


    value = patients unless patients.blank?
  end

  def cum_total_tb_w2yrs(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                             LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.pulmonary_tuberculosis_last_2_years = 'Yes' OR
                                                 ft1.who_stages_criteria_present = 'Tuberculosis (PTB or EPTB) within the last 2 years')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def new_tb_w2yrs(start_date=Time.now, end_date=Time.now, section=nil)
    value = [] 
    patients = [] 

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    @new_current_tb_pat_ids = new_total_current_tb(start_date,end_date)
    @new_total_tb_2yrs = new_total_tb_w2yrs(start_date,end_date)
    
    @new_current_tb_pat_ids = [] if @new_current_tb_pat_ids.blank?
    @new_total_tb_2yrs = [] if @new_total_tb_2yrs.blank?
    
    patients = (@new_total_tb_2yrs - @new_current_tb_pat_ids)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_tb_w2yrs(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    @cum_current_tb_ids = cum_total_current_tb(@@first_registration_date, end_date)
    @cum_total_tb_2yrs = cum_total_tb_w2yrs(@@first_registration_date, end_date)

    @cum_current_tb_ids = [] if @cum_current_tb_ids.blank?
    @cum_total_tb_2yrs = [] if @cum_total_tb_2yrs.blank?

    patients = (@cum_total_tb_2yrs - @cum_current_tb_ids)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  ##########No TB
  def new_no_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []; patients = []

    start_date = @@start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    
    @total_patients_reg = new_total_patients_reg(start_date,end_date)
    @total_tb_w2yrs = new_total_tb_w2yrs(start_date,end_date)
    @total_current_tb = new_total_current_tb(start_date,end_date)
    
    patients = (@total_patients_reg.to_a - (@total_tb_w2yrs.to_a + @total_current_tb.to_a))

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_no_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []; patients = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    @cum_patients_reg = cum_total_patients_reg(@@first_registration_date,end_date)
    @cum_tb_w2yrs = cum_total_tb_w2yrs(@@first_registration_date,end_date)
    @cum_current_tb = cum_total_current_tb(@@first_registration_date,end_date)

    patients = (@cum_patients_reg.to_a - (@cum_tb_w2yrs.to_a + @cum_current_tb.to_a))

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  ##########Kaposis Sarcoma
  def new_ks(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                               LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}' 
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.kaposis_sarcoma = 'Yes'
                                                 OR ft1.who_stages_criteria_present = 'Kaposis sarcoma')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def cum_ks(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc 
                                             LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.kaposis_sarcoma = 'Yes'
                                                 OR ft1.who_stages_criteria_present = 'Kaposis sarcoma')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def total_patients_died(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT 
                                        fct.patient_id
                                    FROM
                                        flat_cohort_table fct
                                    WHERE
                                        fct.earliest_start_date <= '2014-06-30 23:59:59'
                                            AND current_state_for_program(fct.patient_id, 1, '2014-06-30 23:59:59') = 3").collect{|p| p.patient_id}
                                               
    value = patients unless patients.blank?
  end

  def died_1st_month(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            
    
    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                       ft2.current_hiv_program_start_date,
                       ft2.current_hiv_program_state, 
                       DATEDIFF(p.death_date, ftc.earliest_start_date) AS death_date_diff
                FROM flat_table2 ft2
	                INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                  INNER JOIN person p on p.person_id = ftc.patient_id AND p.voided = 0
                WHERE current_state_for_program(ft2.patient_id, 1, '#{end_date}') = 3
                AND ftc.earliest_start_date <= '#{end_date}'
                GROUP BY ftc.patient_id
                HAVING death_date_diff BETWEEN 0 AND 30.4375").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def died_2nd_month(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                       ft2.current_hiv_program_start_date,
                       ft2.current_hiv_program_state,
                       DATEDIFF(p.death_date, ftc.earliest_start_date) AS death_date_diff
                FROM flat_table2 ft2
	                INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                  INNER JOIN person p on p.person_id = ftc.patient_id AND p.voided = 0
                WHERE current_state_for_program(ft2.patient_id, 1, '#{end_date}') = 3
                AND ftc.earliest_start_date <= '#{end_date}'
                GROUP BY ftc.patient_id
                HAVING death_date_diff BETWEEN 30.4375 AND 60.875").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def died_3rd_month(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                       ft2.current_hiv_program_start_date,
                       ft2.current_hiv_program_state, 
                       DATEDIFF(p.death_date, ftc.earliest_start_date) AS death_date_diff
                FROM flat_table2 ft2
	                INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                  INNER JOIN person p on p.person_id = ftc.patient_id AND p.voided = 0
                WHERE current_state_for_program(ft2.patient_id, 1, '#{end_date}') = 3
                AND ftc.earliest_start_date <= '#{end_date}'
                GROUP BY ftc.patient_id
                HAVING death_date_diff BETWEEN 60.875 AND 91.3125").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def died_after_3rd_month(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                       ft2.current_hiv_program_start_date,
                       ft2.current_hiv_program_state, 
                       DATEDIFF(p.death_date, ftc.earliest_start_date) AS death_date_diff
                FROM flat_table2 ft2
	                INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                  INNER JOIN person p on p.person_id = ftc.patient_id AND p.voided = 0
                WHERE current_state_for_program(ft2.patient_id, 1, '#{end_date}') = 3
                AND ftc.earliest_start_date <= '#{end_date}'
                GROUP BY ftc.patient_id
                HAVING death_date_diff BETWEEN 91.3125 AND 1000000").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def died_total(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = total_patients_died(start_date,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def patients_stopped_treatment(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT 
                                              fct.patient_id
                                          FROM
                                              flat_cohort_table fct
                                          WHERE
                                              fct.earliest_start_date <= '#{end_date}'
                                          AND 
                                             current_state_for_program(fct.patient_id, 1, '#{end_date}') = 6").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end
  
  def stopped(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = patients_stopped_treatment(nil,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def patients_transfered_out(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = FlatCohortTable.find_by_sql("SELECT 
                                              fct.patient_id
                                          FROM
                                              flat_cohort_table fct
                                          WHERE
                                              fct.earliest_start_date <= '#{end_date}'
                                          AND 
                                             current_state_for_program(fct.patient_id, 1, '#{end_date}') = 2").collect{|p| p.patient_id}


    value = patients unless patients.blank?
  end

  def transfered(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = @@end_date.to_date.strftime('%Y-%m-%d 23:59:59')                            

    patients = patients_transfered_out(nil,end_date)

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def unknown_outcome(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    #to be polished
    @total_registered = cum_total_patients_reg(@@first_registration_date,@@end_date)
    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)
    @defaulted_patients = art_defaulters
		@died_total = total_patients_died(nil,@@end_date)
		@stopped_taking_arvs = patients_stopped_treatment(nil,@@end_date)
    @tranferred_out = patients_transfered_out(nil,@@end_date)

    patients = @total_registered.to_a  - ($total_alive_and_on_art.to_a + @defaulted_patients.to_a + @died_total.to_a + @stopped_taking_arvs.to_a + @tranferred_out.to_a) 

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n1a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '1A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n1p(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '1P'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n2a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '2A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n2p(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '2P'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}
                  
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n3a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '3A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}
                  
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n3p(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '3P'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n4a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '4A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n4p(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '4P'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n5a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '5A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n6a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '6A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n7a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '7A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n8a(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '8A'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def n9p(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = '9P'
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def non_std(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, ft2.regimen_category AS regimen_category
                    FROM flat_table2 ft2
	                    INNER JOIN encounter enc on enc.encounter_id = ft2.regimen_category_enc_id AND enc.encounter_type = 54
                    WHERE ft2.patient_id IN (#{$total_alive_and_on_art.join(',')}) 
                    AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
			                                            WHERE e1.patient_id = enc.patient_id
                                                  AND e1.encounter_type = enc.encounter_type  
			                                            AND e1.encounter_datetime <= '#{end_date}'
                                                  AND e1.voided = 0)
                    AND ft2.regimen_category = ''
                    GROUP BY ft2.patient_id").collect{|p| p.patient_id}
    
    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def tb_no_suspect(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, 
                       ft2.tb_status_tb_not_suspected_enc_id,
                       ft2.tb_status_tb_not_suspected
                FROM flat_table2 ft2
                  INNER JOIN encounter enc on enc.encounter_id = ft2.tb_status_tb_not_suspected_enc_id 
                                        AND enc.encounter_type = 53
                WHERE ft2.tb_status_tb_not_suspected IS NOT NULL
                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                  WHERE e1.patient_id = enc.patient_id
                                              AND e1.encounter_type = enc.encounter_type  
							                  AND e1.encounter_datetime <= '#{end_date}'
                                              AND e1.voided = 0)
                AND ft2.tb_status_tb_not_suspected = 'Yes'
                GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def tb_suspected(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, 
                       ft2.tb_status_tb_suspected_enc_id,
                       ft2.tb_status_tb_suspected
                FROM flat_table2 ft2
                  INNER JOIN encounter enc on enc.encounter_id = ft2.tb_status_tb_suspected_enc_id 
                                        AND enc.encounter_type = 53
                WHERE ft2.tb_status_tb_suspected IS NOT NULL
                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                  WHERE e1.patient_id = enc.patient_id
                                              AND e1.encounter_type = enc.encounter_type  
							                  AND e1.encounter_datetime <= '#{end_date}'
                                              AND e1.voided = 0)
                AND ft2.tb_status_tb_suspected = 'Yes'
                GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def tb_confirm_not_treat(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, 
                       ft2.tb_status_confirmed_tb_not_on_treatment_enc_id,
                       ft2.tb_status_confirmed_tb_not_on_treatment
                FROM flat_table2 ft2
                  INNER JOIN encounter enc on enc.encounter_id = ft2.tb_status_confirmed_tb_not_on_treatment_enc_id 
                                        AND enc.encounter_type = 53
                WHERE ft2.tb_status_confirmed_tb_not_on_treatment IS NOT NULL
                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                  WHERE e1.patient_id = enc.patient_id
                                              AND e1.encounter_type = enc.encounter_type  
							                  AND e1.encounter_datetime <= '#{end_date}'
                                              AND e1.voided = 0)
                AND ft2.tb_status_confirmed_tb_not_on_treatment = 'Yes'
                GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def tb_confirmed(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, 
                       ft2.tb_status_confirmed_tb_on_treatment_enc_id,
                       ft2.tb_status_confirmed_tb_on_treatment
                FROM flat_table2 ft2
                  INNER JOIN encounter enc on enc.encounter_id = ft2.tb_status_confirmed_tb_on_treatment_enc_id 
                                        AND enc.encounter_type = 53
                WHERE ft2.tb_status_confirmed_tb_on_treatment IS NOT NULL
                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                  WHERE e1.patient_id = enc.patient_id
                                              AND e1.encounter_type = enc.encounter_type  
							                  AND e1.encounter_datetime <= '#{end_date}'
                                              AND e1.voided = 0)
                AND ft2.tb_status_confirmed_tb_on_treatment = 'Yes'
                GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def unknown_tb(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id, 
                       ft2.tb_status_unknown_enc_id,
                       ft2.tb_status_unknown
                FROM flat_table2 ft2
                  INNER JOIN encounter enc on enc.encounter_id = ft2.tb_status_unknown_enc_id 
                                        AND enc.encounter_type = 53
                WHERE ft2.tb_status_unknown IS NOT NULL
                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                  WHERE e1.patient_id = enc.patient_id
                                              AND e1.encounter_type = enc.encounter_type  
							                  AND e1.encounter_datetime <= '#{end_date}'
                                              AND e1.voided = 0)
                AND ft2.tb_status_unknown = 'Yes'
                GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
    render :text => value.to_json

  end

  def drug_induced_p_neu(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                                ft2.drug_induced_peripheral_neuropathy_enc_id, 
                                ft2.drug_induced_peripheral_neuropathy 
                              FROM flat_table2 ft2
                                INNER JOIN encounter enc on enc.encounter_id = ft2.drug_induced_peripheral_neuropathy_enc_id
                                         AND enc.encounter_type = 53
                              WHERE ft2.drug_induced_peripheral_neuropathy IS NOT NULL 
                              AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                              AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                              WHERE e1.patient_id = enc.patient_id
                                                            AND e1.encounter_type = enc.encounter_type  
							                                              AND e1.encounter_datetime <= '#{end_date}'
                                                            AND e1.voided = 0)
                              GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def drug_induced_leg_pain(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                                  ft2.drug_induced_leg_pain_numbness_enc_id, 
                                  ft2.drug_induced_leg_pain_numbness
                                FROM flat_table2 ft2
                                  INNER JOIN encounter enc on enc.encounter_id = ft2.drug_induced_leg_pain_numbness_enc_id
                                   AND enc.encounter_type = 53
                                WHERE ft2.drug_induced_leg_pain_numbness IS NOT NULL 
                                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                                WHERE e1.patient_id = enc.patient_id
                                                              AND e1.encounter_type = enc.encounter_type  
							                                                AND e1.encounter_datetime <= '#{end_date}'
                                                              AND e1.voided = 0)
                                GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def drug_induced_hepatitis(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                                    ft2.drug_induced_hepatitis_enc_id, 
                                    ft2.drug_induced_hepatitis
                                  FROM flat_table2 ft2
                                    INNER JOIN encounter enc on enc.encounter_id = ft2.drug_induced_hepatitis_enc_id
                                     AND enc.encounter_type = 53
                                  WHERE ft2.drug_induced_hepatitis IS NOT NULL 
                                  AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                                  AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                                  WHERE e1.patient_id = enc.patient_id
                                                                AND e1.encounter_type = enc.encounter_type  
							                                                  AND e1.encounter_datetime <= '#{end_date}'
                                                                AND e1.voided = 0)
                                  GROUP BY ft2.patient_id").collect{|p| p.patient_id}
    value = patients unless patients.blank?
  end

  def drug_induced_skin_rash(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                                    ft2.drug_induced_skin_rash_enc_id, 
                                    ft2.drug_induced_skin_rash
                                  FROM flat_table2 ft2
                                    INNER JOIN encounter enc on enc.encounter_id = ft2.drug_induced_skin_rash_enc_id
                                     AND enc.encounter_type = 53
                                  WHERE ft2.drug_induced_skin_rash IS NOT NULL 
                                  AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                                  AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                                  WHERE e1.patient_id = enc.patient_id
                                                                AND e1.encounter_type = enc.encounter_type  
							                                                  AND e1.encounter_datetime <= '#{end_date}'
                                                                AND e1.voided = 0)
                                  GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def drug_induced_jaundice(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                                  ft2.drug_induced_jaundice_enc_id, 
                                  ft2.drug_induced_jaundice
                                FROM flat_table2 ft2
                                  INNER JOIN encounter enc on enc.encounter_id = ft2.drug_induced_jaundice_enc_id
                                   AND enc.encounter_type = 53
                                WHERE ft2.drug_induced_jaundice IS NOT NULL 
                                AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                                AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                                WHERE e1.patient_id = enc.patient_id
                                                              AND e1.encounter_type = enc.encounter_type  
							                                                AND e1.encounter_datetime <= '#{end_date}'
                                                              AND e1.voided = 0)
                                GROUP BY ft2.patient_id").collect{|p| p.patient_id}
    value = patients unless patients.blank?
  end

  def side_effects(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    if !drug_induced_p_neu(end_date).blank?
      drug_induced_p_neu(end_date).each do |patient|
        patients << patient
      end
    end
    
    if !drug_induced_leg_pain(end_date).blank?
      drug_induced_leg_pain(end_date).each  do |patient|
        patients << patient
      end
    end

    if !drug_induced_hepatitis(end_date).blank?
      drug_induced_hepatitis(end_date).each  do |patient|
        patients << patient
      end
    end

    if !drug_induced_skin_rash(end_date).blank?
      drug_induced_skin_rash(end_date).each  do |patient|
        patients << patient
      end
    end
    
    if !drug_induced_jaundice(end_date).blank?
      drug_induced_jaundice(end_date).each  do |patient|
        patients << patient
      end
    end

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def missed_7plus_one(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                        ft2.what_was_the_patient_adherence_for_this_drug1_enc_id, 
                        ft2.what_was_the_patient_adherence_for_this_drug1
                      FROM flat_table2 ft2
                        INNER JOIN encounter enc on enc.encounter_id = ft2.what_was_the_patient_adherence_for_this_drug1_enc_id AND enc.encounter_type = 68
                      WHERE ft2.what_was_the_patient_adherence_for_this_drug1 IS NOT NULL
                      AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                      AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                      WHERE e1.patient_id = enc.patient_id
                                                    AND e1.encounter_type = enc.encounter_type  
							                                      AND e1.encounter_datetime <= '#{end_date}'
                                                    AND e1.voided = 0)
                      AND (ft2.what_was_the_patient_adherence_for_this_drug1 < 95)
                      GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def missed_7plus_two(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                        ft2.what_was_the_patient_adherence_for_this_drug2_enc_id, 
                        ft2.what_was_the_patient_adherence_for_this_drug2
                      FROM flat_table2 ft2
                        INNER JOIN encounter enc on enc.encounter_id = ft2.what_was_the_patient_adherence_for_this_drug2_enc_id AND enc.encounter_type = 68
                      WHERE ft2.what_was_the_patient_adherence_for_this_drug3 IS NOT NULL
                      AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                      AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                      WHERE e1.patient_id = enc.patient_id
                                                    AND e1.encounter_type = enc.encounter_type  
							                                      AND e1.encounter_datetime <= '#{end_date}'
                                                    AND e1.voided = 0)
                      AND (ft2.what_was_the_patient_adherence_for_this_drug2 < 95)
                      GROUP BY ft2.patient_id").collect{|p| p.patient_id}

   
    value = patients unless patients.blank?
  end

  def missed_7plus_three(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                        ft2.what_was_the_patient_adherence_for_this_drug3_enc_id, 
                        ft2.what_was_the_patient_adherence_for_this_drug3
                      FROM flat_table2 ft2
                        INNER JOIN encounter enc on enc.encounter_id = ft2.what_was_the_patient_adherence_for_this_drug3_enc_id AND enc.encounter_type = 68
                      WHERE ft2.what_was_the_patient_adherence_for_this_drug3 IS NOT NULL
                      AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                      AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                      WHERE e1.patient_id = enc.patient_id
                                                    AND e1.encounter_type = enc.encounter_type  
							                                      AND e1.encounter_datetime <= '#{end_date}'
                                                    AND e1.voided = 0)
                      AND (ft2.what_was_the_patient_adherence_for_this_drug3 < 95)
                      GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def missed_7plus_four(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                        ft2.what_was_the_patient_adherence_for_this_drug4_enc_id, 
                        ft2.what_was_the_patient_adherence_for_this_drug4
                      FROM flat_table2 ft2
                        INNER JOIN encounter enc on enc.encounter_id = ft2.what_was_the_patient_adherence_for_this_drug4_enc_id AND enc.encounter_type = 68
                      WHERE ft2.what_was_the_patient_adherence_for_this_drug4 IS NOT NULL
                      AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                      AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                      WHERE e1.patient_id = enc.patient_id
                                                    AND e1.encounter_type = enc.encounter_type  
							                                      AND e1.encounter_datetime <= '#{end_date}'
                                                    AND e1.voided = 0)
                      AND (ft2.what_was_the_patient_adherence_for_this_drug4 < 95)
                      GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def missed_7plus_five(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                        ft2.what_was_the_patient_adherence_for_this_drug5_enc_id, 
                        ft2.what_was_the_patient_adherence_for_this_drug5
                      FROM flat_table2 ft2
                        INNER JOIN encounter enc on enc.encounter_id = ft2.what_was_the_patient_adherence_for_this_drug5_enc_id AND enc.encounter_type = 68
                      WHERE ft2.what_was_the_patient_adherence_for_this_drug5 IS NOT NULL
                      AND ft2.patient_id IN (#{$total_alive_and_on_art.join(',')})
                      AND enc.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
							                                      WHERE e1.patient_id = enc.patient_id
                                                    AND e1.encounter_type = enc.encounter_type  
							                                      AND e1.encounter_datetime <= '#{end_date}'
                                                    AND e1.voided = 0)
                      AND (ft2.what_was_the_patient_adherence_for_this_drug5 < 95)
                      GROUP BY ft2.patient_id").collect{|p| p.patient_id}

    value = patients unless patients.blank?
  end

  def missed_7plus(start_date=Time.now, end_date=Time.now, section=nil)
    value = []
    patients = []
    
    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    if !missed_7plus_one(end_date).blank?
      missed_7plus_one(end_date).each do |patient|
        patients << patient
      end
    end

    if !missed_7plus_two(end_date).blank?
      missed_7plus_two(end_date).each  do |patient|
        patients << patient
      end
    end

    if !missed_7plus_three(end_date).blank?
      missed_7plus_three(end_date).each  do |patient|
        patients << patient
      end
    end

    if !missed_7plus_four(end_date).blank?
      missed_7plus_four(end_date).each  do |patient|
        patients << patient
      end
    end

    if !missed_7plus_five(end_date).blank?
      missed_7plus_five(end_date).each  do |patient|
        patients << patient
      end
    end

    value = patients unless patients.blank?
    render :text => value.to_json
  end

  def missed_0_6(start_date=Time.now, end_date=Time.now, section=nil)
    value = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    value = []
    patients = []

    end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

    if !missed_7plus_one(end_date).blank?
      missed_7plus_one(end_date).each do |patient|
        patients << patient
      end
    end

    if !missed_7plus_two(end_date).blank?
      missed_7plus_two(end_date).each  do |patient|
        patients << patient
      end
    end

    if !missed_7plus_three(end_date).blank?
      missed_7plus_three(end_date).each  do |patient|
        patients << patient
      end
    end

    if !missed_7plus_four(end_date).blank?
      missed_7plus_four(end_date).each  do |patient|
        patients << patient
      end
    end

    if !missed_7plus_five(end_date).blank?
      missed_7plus_five(end_date).each  do |patient|
        patients << patient
      end
    end

    $total_alive_and_on_art ||= total_alive_and_on_art(defaulted_patients = art_defaulters)

    total_alive = $total_alive_and_on_art.to_a

    value = (total_alive  - patients)

    value =  value unless value.blank?
    render :text => value.to_json
  end

  def cohort_field
    @@start_date = params["start_date"]
    @@end_date = params["end_date"]

    if params["field"]

      if params["start_date"]
        start_date = params["start_date"]
      else
        start_date = Time.now.strftime("%Y-%m-%d")
      end
      if params["end_date"]
        end_date = params["end_date"]
      else
        end_date = Time.now.strftime("%Y-%m-%d")
      end

      case params["field"]
      when "regimens"
        regimens(start_date, end_date, params["field"])
      when "defaulters"
        art_defaulters(start_date, end_date, params["field"])    
      when "total_alive_and_on_art"
        total_alive_and_on_art(start_date, end_date, params["field"])
      when "defaulted"
        defaulted(start_date, end_date, params["field"])    
      when "total_on_art"
        total_on_art(start_date, end_date, params["field"])       
      when "new_total_reg"
        new_total_reg(start_date, end_date, params["field"])
      when "cum_total_reg"
        cum_total_reg(start_date, end_date, params["field"])
      when "new_ft"
        new_ft(start_date, end_date, params["field"])
      when "cum_ft"
        cum_ft(start_date, end_date, params["field"])
      when "new_re"
        new_re(start_date, end_date, params["field"])
      when "cum_re"
        cum_re(start_date, end_date, params["field"])
      when "new_ti"
        new_ti(start_date, end_date, params["field"])
      when "cum_ti"
        cum_ti(start_date, end_date, params["field"])
      when "new_males"
        new_males(start_date, end_date, params["field"])
      when "cum_males"
        cum_males(start_date, end_date, params["field"])
      when "new_non_preg"
        new_non_preg(start_date, end_date, params["field"])
      when "cum_non_preg"
        cum_non_preg(start_date, end_date, params["field"])
      when "new_preg_all_age"
        new_preg_all_age(start_date, end_date, params["field"])
      when "cum_preg_all_age"
        cum_preg_all_age(start_date, end_date, params["field"])
      when "new_a"
        new_a(start_date, end_date, params["field"])
      when "cum_a"
        cum_a(start_date, end_date, params["field"])
      when "new_b"
        new_b(start_date, end_date, params["field"])
      when "cum_b"
        cum_b(start_date, end_date, params["field"])
      when "new_c"
        new_c(start_date, end_date, params["field"])
      when "cum_c"
        cum_c(start_date, end_date, params["field"])
      when "new_unk_age"
        new_unk_age(start_date, end_date, params["field"])
      when "cum_unk_age"
        cum_unk_age(start_date, end_date, params["field"])
      when "new_pres_hiv"
        new_pres_hiv(start_date, end_date, params["field"])
      when "cum_pres_hiv"
        cum_pres_hiv(start_date, end_date, params["field"])
      when "new_conf_hiv"
        new_conf_hiv(start_date, end_date, params["field"])
      when "cum_conf_hiv"
        cum_conf_hiv(start_date, end_date, params["field"])
      when "new_who_1_2"
        new_who_1_2(start_date, end_date, params["field"])
      when "cum_who_1_2"
        cum_who_1_2(start_date, end_date, params["field"])
      when "new_who_2"
        new_who_2(start_date, end_date, params["field"])
      when "cum_who_2"
        cum_who_2(start_date, end_date, params["field"])
      when "new_children"
        new_children(start_date, end_date, params["field"])
      when "cum_children"
        cum_children(start_date, end_date, params["field"])
      when "new_breastfeed"
        new_breastfeed(start_date, end_date, params["field"])
      when "cum_breastfeed"
        cum_breastfeed(start_date, end_date, params["field"])
      when "new_preg"
        new_preg(start_date, end_date, params["field"])
      when "cum_preg"
        cum_preg(start_date, end_date, params["field"])
      when "new_who_3"
        new_who_3(start_date, end_date, params["field"])
      when "cum_who_3"
        cum_who_3(start_date, end_date, params["field"])
      when "new_who_4"
        new_who_4(start_date, end_date, params["field"])
      when "cum_who_4"
        cum_who_4(start_date, end_date, params["field"])
      when "new_other_reason"
        new_other_reason(start_date, end_date, params["field"])
      when "cum_other_reason"
        cum_other_reason(start_date, end_date, params["field"])
      when "new_no_tb"
        new_no_tb(start_date, end_date, params["field"])
      when "cum_no_tb"
        cum_no_tb(start_date, end_date, params["field"])
      when "new_tb_w2yrs"
        new_tb_w2yrs(start_date, end_date, params["field"])
      when "cum_tb_w2yrs"
        cum_tb_w2yrs(start_date, end_date, params["field"])
      when "new_current_tb"
        new_current_tb(start_date, end_date, params["field"])
      when "cum_current_tb"
        cum_current_tb(start_date, end_date, params["field"])
      when "new_ks"
        new_ks(start_date, end_date, params["field"])
      when "cum_ks"
        cum_ks(start_date, end_date, params["field"])
      when "died_1st_month"
        died_1st_month(start_date, end_date, params["field"])
      when "died_2nd_month"
        died_2nd_month(start_date, end_date, params["field"])
      when "died_3rd_month"
        died_3rd_month(start_date, end_date, params["field"])
      when "died_after_3rd_month"
        died_after_3rd_month(start_date, end_date, params["field"])
      when "died_total"
        died_total(start_date, end_date, params["field"])
      when "stopped"
        stopped(start_date, end_date, params["field"])
      when "transfered"
        transfered(start_date, end_date, params["field"])
      when "unknown_outcome"
        unknown_outcome(start_date, end_date, params["field"])
      when "n1a"
        n1a(start_date, end_date, params["field"])
      when "n1p"
        n1p(start_date, end_date, params["field"])
      when "n2a"
        n2a(start_date, end_date, params["field"])
      when "n2p"
        n2p(start_date, end_date, params["field"])
      when "n3a"
        n3a(start_date, end_date, params["field"])
      when "n3p"
        n3p(start_date, end_date, params["field"])
      when "n4a"
        n4a(start_date, end_date, params["field"])
      when "n4p"
        n4p(start_date, end_date, params["field"])
      when "n5a"
        n5a(start_date, end_date, params["field"])
      when "n6a"
        n6a(start_date, end_date, params["field"])
      when "n7a"
        n7a(start_date, end_date, params["field"])
      when "n8a"
        n8a(start_date, end_date, params["field"])
      when "n9p"
        n9p(start_date, end_date, params["field"])
      when "non_std"
        non_std(start_date, end_date, params["field"])
      when "tb_no_suspect"
        tb_no_suspect(start_date, end_date, params["field"])
      when "tb_suspected"
        tb_suspected(start_date, end_date, params["field"])
      when "tb_confirm_not_treat"
        tb_confirm_not_treat(start_date, end_date, params["field"])
      when "tb_confirmed"
        tb_confirmed(start_date, end_date, params["field"])
      when "unknown_tb"
        unknown_tb(start_date, end_date, params["field"])
      when "current_site"
        current_site
      when "quarter"
        quarter(start_date, end_date, params["field"])
      when "side_effects"
        side_effects(start_date, end_date, params["field"])
      when "missed_0_6"
        missed_0_6(start_date, end_date, params["field"])
      when "missed_7plus"
        missed_7plus(start_date, end_date, params["field"])
      when "missed_7plus_one"
        missed_7plus_one(start_date, end_date, params["field"])
      when "missed_7plus_two"
        missed_7plus_two(start_date, end_date, params["field"])
      when "missed_7plus_three"
        missed_7plus_three(start_date, end_date, params["field"])
      when "missed_7plus_four"
        missed_7plus_four(start_date, end_date, params["field"])
      when "missed_7plus_five"
        missed_7plus_five(start_date, end_date, params["field"])
      when "drug_induced_p_neu"
        drug_induced_p_neu(start_date, end_date, params["field"])
      when "drug_induced_leg_pain"
        drug_induced_leg_pain(start_date, end_date, params["field"])
      when "drug_induced_hepatitis"
        drug_induced_hepatitis(start_date, end_date, params["field"])
      when "drug_induced_skin_rash"
        drug_induced_skin_rash(start_date, end_date, params["field"])
      when "drug_induced_jaundice"
        drug_induced_jaundice(start_date, end_date, params["field"])
      when "new_patient_pregnant"
        new_patient_pregnant(start_date, end_date, params["field"])      
      when "cum_patient_pregnant"
        cum_patient_pregnant(start_date, end_date, params["field"])      
      else
        reply(params["field"])
      end
    end
  end

  def survival_analysis_field
    
    @data = []
    if params[:start] and params[:end]

      @start_date =   params[:start]
      @end_date   =   params[:end]
      
      @data       =   eval("#{params[:field].strip}_#{params[:cat].strip}("+
          "'#{params[:start].to_date.to_s} 00:00:00', "+
          " '#{params[:end].to_date.to_s} 23:59:59')")
      
      $survival_logger["#{params[:field].strip}_#{params[:cat].strip}" +
          "_#{params[:start].to_date.to_s}_#{params[:end].to_date.to_s}"] = @data     
    end
    
    render :text => @data.to_json
  end

  def new_reg_generic(start_date, end_date, join_string = "")

    key = "new_reg_generic_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    return $survival_logger[key] if !$survival_logger[key].blank? and join_string.blank?
    
    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            #{join_string}
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            GROUP BY ftc.patient_id").map(&:patient_id)
    return patients
  end

  def on_art_generic(start_date, end_date, join_string = "")

    key = "on_art_generic_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    return $survival_logger[key] if !$survival_logger[key].blank? and join_string.blank?
    
    defaulters = ([-1] + defaulter_generic(start_date, end_date, join_string)).join(",")
    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                      ft2.current_hiv_program_start_date, ft2.current_hiv_program_state
                    FROM flat_table2 ft2
	                    INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                    WHERE ft2.visit_date = (SELECT max(DATE(encounter_datetime)) FROM encounter
				                                WHERE patient_id = ftc.patient_id
				                                AND voided = 0
				                                AND encounter_datetime <= '#{end_date}')
                    AND ft2.current_hiv_program_state = 'On antiretrovirals'
                    #{join_string}
                    AND ftc.earliest_start_date >= '#{start_date}'
                    AND ftc.earliest_start_date <= '#{end_date}'
                    AND ftc.patient_id NOT IN (#{defaulters})
                    GROUP BY ft2.patient_id").map(&:patient_id)
    return patients
  end

  def dead_generic(start_date, end_date, join_string = "")

    key = "dead_generic_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    return $survival_logger[key] if !$survival_logger[key].blank? and join_string.blank?
    
    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id,
                       ft2.current_hiv_program_start_date,
                       ft2.current_hiv_program_state                       
                FROM flat_table2 ft2
	                INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                  INNER JOIN person p on p.person_id = ftc.patient_id AND p.voided = 0
                WHERE ft2.visit_date = (SELECT max(DATE(encounter_datetime)) FROM encounter
				                        WHERE patient_id = ftc.patient_id
				                        AND voided = 0
				                        AND encounter_datetime <= '#{end_date}')
                 AND ftc.earliest_start_date >= '#{start_date}'
                 AND ftc.earliest_start_date <= '#{end_date}'
                 #{join_string}
                AND ft2.current_hiv_program_state = 'Patient died'").map(&:patient_id).uniq
    return patients
  end
  
  def defaulter_generic(start_date, end_date, join_string = "")

    key = "defaulter_generic_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    return $survival_logger[key] if !$survival_logger[key].blank? and join_string.blank?
    
    patients = FlatCohortTable.find_by_sql("SELECT ftc.patient_id
                                      FROM flat_cohort_table ftc
                                      WHERE ftc.hiv_program_state = 'Defaulter'
                                            AND ftc.hiv_program_start_date <= '#{end_date}'
                                            AND ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            #{join_string}
                                            AND current_state_for_program(patient_id, 1, '#{end_date}') NOT IN (6, 2, 3)").map(&:patient_id).uniq
    return patients
  end

  def art_stop_generic(start_date, end_date, join_string = "")

    key = "art_stop_generic_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    return $survival_logger[key] if !$survival_logger[key].blank? and join_string.blank?
    
    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id                                        
                                    FROM flat_table2 ft2
                                        INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                                    WHERE visit_date = (SELECT max(DATE(encounter_datetime)) from encounter
                                        WHERE patient_id = ft2.patient_id
                                        AND voided = 0
                                        AND encounter_datetime <= '#{end_date}')
                                    AND ftc.earliest_start_date >= '#{start_date}'
                                    AND ftc.earliest_start_date <= '#{end_date}'
                                    #{join_string}
                                    AND ft2.current_hiv_program_state = 'Treatment stopped'").map(&:patient_id).uniq
    return patients
  end

  def transfer_out_generic(start_date, end_date, join_string = "")

    key = "transfer_out_generic_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    return $survival_logger[key] if !$survival_logger[key].blank? and join_string.blank?
    
    patients = FlatCohortTable.find_by_sql("SELECT ft2.patient_id
                FROM flat_table2 ft2
                    INNER JOIN flat_cohort_table ftc ON ftc.patient_id = ft2.patient_id
                WHERE visit_date = (SELECT max(DATE(encounter_datetime)) from encounter
                                    WHERE patient_id = ft2.patient_id
				                            AND voided = 0
					                          AND encounter_datetime <= '#{end_date}')
                AND ftc.earliest_start_date >= '#{start_date}'
                AND ftc.earliest_start_date <= '#{end_date}'
                #{join_string}
                AND ft2.current_hiv_program_state IN ('Patient transferred out','Transferred internally', " +
        "'Patient transferred (External facility)', 'Patient transferred (Within facility)')").map(&:patient_id).uniq
    return patients
  end

  def unknown_generic(start_date, end_date)

    patients = new_reg_generic(start_date, end_date) - (on_art_generic(start_date, end_date) +
        dead_generic(start_date, end_date) + defaulter_generic(start_date, end_date) + 
        art_stop_generic(start_date, end_date) + transfer_out_generic(start_date, end_date))
    return patients
  end

  def new_reg_children(start_date, end_date)

    key = "new_reg_children_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    patients = $survival_logger[key].blank? ? new_reg_generic(start_date, end_date, @@children_join) : $survival_logger[key]
    return patients
  end

  def on_art_children(start_date, end_date)

    key = "on_art_children_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    patients = $survival_logger[key].blank? ? on_art_generic(start_date, end_date, @@children_join) : $survival_logger[key]
    return patients
  end

  def dead_children(start_date, end_date)

    key = "dead_children_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    patients = $survival_logger[key].blank? ? dead_generic(start_date, end_date, @@children_join) : $survival_logger[key]
    return patients
  end

  def defaulter_children(start_date, end_date)

    key = "defaulter_children_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    patients = $survival_logger[key].blank? ? defaulter_generic(start_date, end_date, @@children_join) : $survival_logger[key]
    return patients
  end

  def art_stop_children(start_date, end_date)

    key = "art_stop_children_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    patients = $survival_logger[key].blank? ? art_stop_generic(start_date, end_date, @@children_join) : $survival_logger[key]
    return patients
  end

  def transfer_out_children(start_date, end_date)

    key = "transfer_out_children_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    patients = $survival_logger[key].blank? ? transfer_out_generic(start_date, end_date, @@children_join) : $survival_logger[key]
    return patients
  end

  def unknown_children(start_date, end_date)

    patients = new_reg_children(start_date, end_date) - (on_art_children(start_date, end_date) +
        dead_children(start_date, end_date) + defaulter_children(start_date, end_date) +
        art_stop_children(start_date, end_date) + transfer_out_children(start_date, end_date))
    return patients
  end

  def new_reg_pmtct(start_date, end_date)

    women_by_reason_for_eligibility = FlatCohortTable.find_by_sql("SELECT ftc.patient_id FROM flat_cohort_table ftc
                                              LEFT OUTER JOIN flat_table1 ft1 ON ft1.patient_id = ftc.patient_id
                                            WHERE ftc.earliest_start_date >= '#{start_date}'
                                            AND ftc.earliest_start_date <= '#{end_date}'
                                            AND (ft1.reason_for_eligibility  = 'Patient pregnant'
                                              OR ft1.reason_for_eligibility = 'Currently breastfeeding child')
                                            GROUP BY ftc.patient_id").collect{|p| p.patient_id}

    women_by_pregnant_encounter = FlatCohortTable.find_by_sql("SELECT
                                      ft1.patient_id
                                  FROM
                                      flat_table1 ft1
                                          INNER join
                                      flat_cohort_table ftc ON ftc.patient_id = ft1.patient_id
                                          INNER JOIN
                                      encounter e ON e.encounter_id = ft1.pregnant_yes_enc_id
                                          and e.voided = 0
                                          AND e.encounter_type = 52
                                  WHERE
                                      (e.encounter_datetime >= '#{start_date}'
                                          AND e.encounter_datetime <= '#{end_date}')
                                          AND (ftc.earliest_start_date >= '#{start_date}'
                                          AND ftc.earliest_start_date <= '#{end_date}')
                                          AND DATEDIFF(ft1.pregnant_yes_v_date,
                                              ftc.earliest_start_date) <= 30
                                          AND DATEDIFF(ft1.pregnant_yes_v_date,
                                              ftc.earliest_start_date) > - 1
                                          AND ft1.pregnant_yes = 'Yes'
                                  GROUP BY ft1.patient_id
                                  UNION ALL
                                  SELECT
                                      ft2.patient_id
                                  FROM
                                      flat_table2 ft2
                                          INNER join
                                      flat_table1 ftc ON ftc.patient_id = ft2.patient_id
                                          INNER JOIN
                                      encounter e ON e.encounter_id = ft2.pregnant_yes_enc_id
                                          and e.voided = 0
                                          AND e.encounter_type = 53
                                  WHERE
                                      (e.encounter_datetime >= '#{start_date}'
                                          AND e.encounter_datetime <= '#{end_date}')
                                          AND (ftc.earliest_start_date >= '#{start_date}'
                                          AND ftc.earliest_start_date <= '#{end_date}')
                                          AND DATEDIFF(ft2.visit_date,
                                              ftc.earliest_start_date) <= 30
                                          AND DATEDIFF(ft2.visit_date,
                                              ftc.earliest_start_date) > - 1
                                          AND ft2.pregnant_yes = 'Yes'
                                  GROUP BY ft2.patient_id").map(&:patient_id)    
    return (women_by_pregnant_encounter | women_by_reason_for_eligibility)
  end

  def on_art_pmtct(start_date, end_date)

    key_a = "on_art_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    on_art = $survival_logger[key_a].blank? ? on_art_generic(start_date, end_date, @@female_join) : $survival_logger[key_a]
    
    key_b = "new_reg_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    all_pb = $survival_logger[key_b].blank? ? new_reg_pmtct(start_date, end_date) : $survival_logger[key_b]
    
    return(on_art & all_pb)
  end

  def dead_pmtct(start_date, end_date)

    key_a = "dead_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    dead = $survival_logger[key_a].blank? ? dead_generic(start_date, end_date, @@female_join) : $survival_logger[key_a]

    key_b = "new_reg_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    all_pb = $survival_logger[key_b].blank? ? new_reg_pmtct(start_date, end_date) : $survival_logger[key_b]
  
    return (dead & all_pb)
  end

  def defaulter_pmtct(start_date, end_date)

    key_a = "defaulter_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    deft = $survival_logger[key_a].blank? ? defaulter_generic(start_date, end_date, @@female_join) : $survival_logger[key_a]

    key_b = "new_reg_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    all_pb = $survival_logger[key_b].blank? ? new_reg_pmtct(start_date, end_date) : $survival_logger[key_b]
    
    return (deft & all_pb)
  end

  def art_stop_pmtct(start_date, end_date)

    key_a = "art_stop_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    art_stop = $survival_logger[key_a].blank? ? art_stop_generic(start_date, end_date, @@female_join) : $survival_logger[key_a]

    key_b = "new_reg_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    all_pb = $survival_logger[key_b].blank? ? new_reg_pmtct(start_date, end_date) : $survival_logger[key_b]

    return (art_stop & all_pb)
  end

  def transfer_out_pmtct(start_date, end_date)

    key_a = "transfer_out_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    t_out = $survival_logger[key_a].blank? ? transfer_out_generic(start_date, end_date, @@female_join) : $survival_logger[key_a]

    key_b = "new_reg_pmtct_#{start_date.to_date.to_s}_#{end_date.to_date.to_s}"
    all_pb = $survival_logger[key_b].blank? ? new_reg_pmtct(start_date, end_date) : $survival_logger[key_b]
    
    return (t_out & all_pb)
  end

  def unknown_pmtct(start_date, end_date)

    patients = new_reg_pmtct(start_date, end_date) - (on_art_pmtct(start_date, end_date) +
        dead_pmtct(start_date, end_date) + defaulter_pmtct(start_date, end_date) +
        art_stop_pmtct(start_date, end_date) + transfer_out_pmtct(start_date, end_date))
    return patients
  end

  def survival_analysis_index
    
    survival_start_date = params[:start_date].to_date
    survival_end_date = params[:end_date].to_date

    @date_ranges = Array.new
    @children_date_ranges = Array.new
    @pregnant_and_breastfeeding_date_ranges = Array.new
    first_registration_date = @@first_registration_date
   
    $survival_logger = {}
 
    if first_registration_date.present?
      while (survival_start_date -= 1.year) >= first_registration_date

        survival_end_date   -= 1.year
        quarter_registration = new_total_patients_reg_with_age(survival_start_date, survival_end_date)

        break if quarter_registration.length == 0
        @date_ranges << {:start_date => survival_start_date,
          :end_date   => survival_end_date
        }
      end

      survival_start_date = params[:start_date].to_date
      survival_end_date = params[:end_date].to_date
      while (survival_start_date -= 1.year) >= first_registration_date

        survival_end_date   -= 1.year
        quarter_registration = new_total_patients_reg_with_age(survival_start_date, survival_end_date, 0, 14)
        break if quarter_registration.length == 0
        @children_date_ranges << {:start_date => survival_start_date,
          :end_date   => survival_end_date
        }
      end

      if  params[:start_date].to_date - 6.months >= "01-07-2011".to_date  #01-07-2011 is when PMTCT started in malawi.
        @pregnant_and_breastfeeding_date_ranges << {:start_date => params[:start_date].to_date - 6.months,
          :end_date   => params[:end_date].to_date - 6.months
        }
      end

      survival_start_date = params[:start_date].to_date
      survival_end_date = params[:end_date].to_date
      while (survival_start_date -= 1.year) >= first_registration_date

        survival_end_date   -= 1.year
        quarter_registration = new_total_patients_reg_with_age(survival_start_date, survival_end_date)
        break if quarter_registration.length == 0 ||  survival_start_date < "01-07-2011".to_date
        @pregnant_and_breastfeeding_date_ranges << {:start_date => survival_start_date,
          :end_date   => survival_end_date
        }
      end
    end
  end
  
end
