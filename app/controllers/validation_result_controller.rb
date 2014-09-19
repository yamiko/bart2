#class ValidationResultController < ApplicationController
#end

class ValidationResultController < ActionController::Base

  def initialize

		@@first_registration_date = FlatCohortTable.find(
		  :first,
		  :order => 'earliest_start_date ASC'
		).earliest_start_date.to_date rescue nil
	end

  def list
    start_date = params[:start_date]
    end_date = params[:end_date]
    resp = []
    (start_date..end_date).each do |date|
      resp << ValidationRule.find_by_sql("SELECT validation_rules.id as rule_id, `desc` as description,
                                  COALESCE((SELECT failures FROM validation_results WHERE rule_id = validation_rules.id
                                  AND date_checked = '#{date}') ,0) AS failures, '#{date}' as date_checked from
                                  validation_rules where validation_rules.type_id = 2").map { |r| {:rule_id => r.rule_id,
                                                                                                   :rule_desc => r.description ,
                                                                                                   :date_checked => r.date_checked,
                                                                                                   :failures => r.failures}}
    end

    respond_to do |format|
      format.json { render :json => resp }
      format.html { render :text => resp.to_yaml }
    end
  end
  
  
  def summary
    start_date = params[:start_date]
    end_date = params[:end_date]
    
    total_rules = ValidationRule.count(:all, :conditions => ['type_id = ?', 2])
    results = ValidationResult.find(
      :all, #:include => :validation_rules,
      :select => "date_checked, COUNT(failures) AS passed, #{total_rules} AS total",
      :conditions => ['date_checked >= ? AND date_checked <= ? AND failures = 0',
                      start_date.to_date, end_date.to_date],                
      :group => 'date_checked' 
     )

    resp = results.map { |r| {:date_checked => r.date_checked.strftime("%Y-%m-%d"),
                               :passed => r.passed,
                               :total => r.total}
                       }
    
    respond_to do |format|
      
      format.json { render :json => resp}

      format.html { render :text => resp.to_yaml }
    end
  end
end
