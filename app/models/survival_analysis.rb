class SurvivalAnalysis

  def self.report(cohort, min_age=nil, max_age=nil)
		
    program_id = Program.find_by_name('HIV PROGRAM').id
    survival_analysis_outcomes = {} ; views={}; months = 12 ; patients_found = true
    survival_end_date = cohort.end_date.to_date ; survival_start_date = cohort.start_date.to_date
    first_registration_date = PatientProgram.find(:first,:conditions =>["program_id = ? AND voided = 0",program_id],
                                                  :order => 'date_enrolled ASC').date_enrolled.to_date rescue nil
    return if first_registration_date.blank?

    date_ranges = []

    while (survival_start_date -= 1.year) >= first_registration_date
      survival_end_date   -= 1.year
      date_ranges << {:start_date => survival_start_date,
                      :end_date   => survival_end_date
      }
    end
	  
    ( date_ranges || [] ).each_with_index do | range ,i |
			transferred = []; arvs =[]; stopped = []; defaulted=[]; dead=[]; unknown =[]
			states = cohort.outcomes(range[:start_date], range[:end_date], cohort.end_date.to_date, program_id, states = nil, min_age, max_age)

			 survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"] = {
        'Number Alive and on ART' => 0,
        'Number Dead' => 0, 'Number Defaulted' => 0 ,
        'Number Stopped Treatment' => 0, 'Number Transferred out' => 0,
        "Section date range" => "#{range[:start_date].strftime('%B %Y')} to #{range[:end_date].strftime('%B %Y')}",
        'Unknown' => 0,'New patients registered for ART' => states.length}
			
      (states || [] ).each do | patient_id , state |
        case state.upcase
          when 'DEFAULTED'
						defaulted << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Defaulted']+=1
          when 'PATIENT TRANSFERRED OUT'
						transferred << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Transferred out']+=1
          when 'PATIENT DIED'
						dead << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Dead']+=1
          when 'TREATMENT STOPPED'
						stopped << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Stopped Treatment']+=1
					when 'STOPPED TAKING ARVS'
						stopped << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Stopped Treatment']+=1
					when 'ON ANTIRETROVIRALS'
						arvs << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Alive and on ART']+=1
          when 'ON ARVS'
						arvs << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Alive and on ART']+=1
					when 'UNKNOWN'
						unknown << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Unknown']+=1
				end
      end
    			views["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"] = {
				"stopped" => stopped,
				"arvs" => arvs,
				"dead" => dead,
				"transferred" => transferred,
				"defaulted" => defaulted,
				"unknown" => unknown
			}
    end

    return survival_analysis_outcomes.sort{|a,b| (a[0].to_i == b[0].to_i) ? a[1].to_i <=> b[1].to_i : a[0].to_i <=> b[0].to_i }, views
	end

	def self.childern_survival_analysis(cohort)
		self.report(cohort, 0, 14)
  end

	def self.pregnant_and_breast_feeding(cohort)
		
		program_id = Program.find_by_name('HIV PROGRAM').id
    survival_analysis_outcomes = {} ; views = {}; months = 12 ; patients_found = true
    survival_end_date = cohort.end_date.to_date ; survival_start_date = cohort.start_date.to_date
    first_registration_date = PatientProgram.find(:first,:conditions =>["program_id = ? AND voided = 0",program_id],
                                                  :order => 'date_enrolled ASC').date_enrolled.to_date rescue nil
    return if first_registration_date.blank?

    date_ranges = []

    while (survival_start_date -= 1.year) >= first_registration_date
      survival_end_date   -= 1.year
      date_ranges << {:start_date => survival_start_date,
                      :end_date   => survival_end_date
      }
    end

	
    ( date_ranges || [] ).each_with_index do | range ,i |
		  transferred = []; arvs =[]; stopped = []; defaulted=[]; dead=[]; unknown =[]
      states = cohort.women_outcomes(range[:start_date], range[:end_date], cohort.end_date.to_date, program_id, states = nil)
			 survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"] = {
        'Number Alive and on ART' => 0,
        'Number Dead' => 0, 'Number Defaulted' => 0 ,
        'Number Stopped Treatment' => 0, 'Number Transferred out' => 0,
        "Section date range" => "#{range[:start_date].strftime('%B %Y')} to #{range[:end_date].strftime('%B %Y')}",
        'Unknown' => 0,'New patients registered for ART' => states.length}

      (states || [] ).each do | patient_id , state |
        case state.upcase
          when 'DEFAULTED'
						defaulted << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Defaulted']+=1
          when 'PATIENT TRANSFERRED OUT'
						transferred << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Transferred out']+=1
          when 'PATIENT DIED'
						dead << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Dead']+=1
          when 'TREATMENT STOPPED'
						stopped << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Stopped Treatment']+=1
					when 'STOPPED TAKING ARVS'
						stopped << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Stopped Treatment']+=1
					when 'ON ANTIRETROVIRALS'
						arvs << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Alive and on ART']+=1
          when 'ON ARVS'
						arvs << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Number Alive and on ART']+=1
					when 'UNKNOWN'
						unknown << patient_id
            survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"]['Unknown']+=1
				end
      end

			views["#{(i + 1)*12} month survival: outcomes by end of #{range[:end_date].strftime('%B %Y')}"] = {
				"stopped" => stopped,
				"arvs" => arvs,
				"dead" => dead,
				"transferred" => transferred,
				"defaulted" => defaulted,
				"unknown" => unknown
			}
    end

    return survival_analysis_outcomes.sort{|a,b| (a[0].to_i == b[0].to_i) ? a[1].to_i <=> b[1].to_i : a[0].to_i <=> b[0].to_i }, views
	end
end
