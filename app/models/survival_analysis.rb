class SurvivalAnalysis

  def self.report(cohort)
		#raise cohort.to_yaml
    program_id = Program.find_by_name('HIV PROGRAM').id
    survival_analysis_outcomes = {} ; months = 12 ; patients_found = true
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
      states = cohort.outcomes(range[:start_date], range[:end_date], cohort.end_date.to_date, program_id) 
      survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{survival_end_date.strftime('%B %Y')}"] = {'Number Alive and on ART' => 0, 
                                'Number Dead' => 0, 'Number Defaulted' => 0 , 'Number Stopped Treatment' => 0, 'Number Transferred out' => 0, 
                                 'Unknown' => 0,'New patients registered for ART' => states.length}

      (states || [] ).each do | patient_id , state |
        case state
          when 'PATIENT TRANSFERRED OUT'
             survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{survival_end_date.strftime('%B %Y')}"]['Number Transferred out']+=1 
          when 'PATIENT DIED'
             survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{survival_end_date.strftime('%B %Y')}"]['Number Dead']+=1 
          when 'TREATMENT STOPPED'
             survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{survival_end_date.strftime('%B %Y')}"]['Number Stopped Treatment']+=1 
          when 'ON ANTIRETROVIRALS'
             survival_analysis_outcomes["#{(i + 1)*12} month survival: outcomes by end of #{survival_end_date.strftime('%B %Y')}"]['Number Alive and on ART']+=1 
        end
      end
    end
    survival_analysis_outcomes.sort
  end

####################################################
=begin
  def survival_analysis(survival_start_date=@start_date,
                        survival_end_date=@end_date,
                        outcome_end_date=@end_date, min_age=nil, max_age=nil)
    # Make sure these are always dates
    survival_start_date = start_date.to_date
    survival_end_date = end_date.to_date
    outcome_end_date = outcome_end_date.to_date

    date_ranges = Array.new
    first_registration_date = PatientRegistrationDate.find(:first,
      :order => 'registration_date').registration_date

    while (survival_start_date -= 1.year) >= first_registration_date
      survival_end_date   -= 1.year
      date_ranges << {:start_date => survival_start_date,
                      :end_date   => survival_end_date
      }
    end

    survival_analysis_outcomes = Array.new

    date_ranges.each_with_index do |date_range, i|
      outcomes_hash = Hash.new(0)
      all_outcomes = self.outcomes(date_range[:start_date], date_range[:end_date], outcome_end_date, min_age, max_age)

      outcomes_hash["Title"] = "#{(i+1)*12} month survival: outcomes by end of #{outcome_end_date.strftime('%B %Y')}"
      outcomes_hash["Start Date"] = date_range[:start_date]
      outcomes_hash["End Date"] = date_range[:end_date]

      survival_cohort = Reports::CohortByRegistrationDate.new(date_range[:start_date], date_range[:end_date])
      if max_age.nil?
        outcomes_hash["Total"] = survival_cohort.patients_started_on_arv_therapy.length rescue all_outcomes.values.sum
      else
        outcomes_hash["Total"] = all_outcomes.values.sum
      end
      outcomes_hash["Unknown"] = outcomes_hash["Total"] - all_outcomes.values.sum
      outcomes_hash["outcomes"] = all_outcomes

      # if there are no patients registered in that quarter, we must have
      # passed the real date when the clinic opened
      break if outcomes_hash["Total"] == 0

      survival_analysis_outcomes << outcomes_hash
    end
    survival_analysis_outcomes
  end
####################################################
=end
end
