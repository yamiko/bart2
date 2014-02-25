class CohortValidation
    
	attr_accessor :cohort_object

	def initialize(cohort_obj)

		self.cohort_object = cohort_obj	
	end

	def get_all_differences
	 
	 #This code runs all methods that start with 'validate_' 
	 #And returns a hash of all return values from such methods
	 #By Kenneth Kapundi	 

		differences = {}
		(self.class.instance_methods(false) - Object.methods).each do |method|
			next if !method.match(/^validate\_/) 
			validation = method.sub(/^validate\_/, "").humanize
			differences[validation] = self.send(method) unless validation.blank?
		end

		return differences
	end
	
	def feed_values(expr, val_arr)
		#This method takes an expression and replaces the curly 
		#brackets with values from the val_arr array based on position.
		#By Kenneth Kapundi
		
		return nil if expr.scan(/\{\w+\}/).length != val_arr.length
		return eval(val_arr.inject(expr){|out_str, val| out_str = out_str.sub(/\{\w+\}/, "#{val.length}"); out_str})				
	end
	
		
	#***************SAMPLE USAGE****************************
	#To be removed later on.
	#By Kenneth Kapundi
	def validate_sample_rule		
		
		validation_rule = ValidationRule.find_by_type_id(1)
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Kaposis Sarcoma'],
				 				self.cohort_object['Newly total registered'], 
			 					self.cohort_object['Newly total registered'],
			 					self.cohort_object['Newly total registered']]
			 					
		return self.feed_values(validation_rule.expr, values)		
	end
	
	def validate_new_total_male_plus_total_pregnant_plus_total_nonpregnant_equals_total_registered
	  
	  # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Newly (registered males + 
    #                               registered females (pregnant) + 
    #                               registered females (non -pregnant)) =
    #                               total registered  
    # Amendments  :

   
	  validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Newly total registered'],
              self.cohort_object['Newly registered male'],
              self.cohort_object['Newly registered women (non-pregnant)'], 
              self.cohort_object['Newly registered women (pregnant)']
                ]
         
    return self.feed_values(validation_rule.expr, values)
	end
	
	def validate_cumulative_total_male_plus_total_pregnant_plus_total_nonpregnant_equals_total_registered
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate cumulative (registered males + 
    #                                   registered females (pregnant) + 
    #                                   registered females (non -pregnant)) =
    #                                   total registered  
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered'],
                self.cohort_object['Total registered male'],
                self.cohort_object['Total registered women (non-pregnant)'], 
                self.cohort_object['Total registered women (pregnant)']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
  
  def validate_cumulative_and_new_total_registered
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Total Registered (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered'],
              self.cohort_object['Newly total registered']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
  
  def validate_cumulative_and_new_patients_initiated_first_time
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate patients initiated first time on ART (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Patients initiated on ART'],
              self.cohort_object['Patients initiated on ART']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
	
	def validate_cumulative_and_new_patients_reinitiated
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Patients reinitiated on ART (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Patients reinitiated on ART'],
              self.cohort_object['Patients reinitiated on ART']
                ]

    return self.feed_values(validation_rule.expr, values)
  end  
  
  def validate_cumulative_and_new_transferedin_on_art
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Patients transfered in on ART (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total transferred in patients'],
              self.cohort_object['Newly transferred in patients']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
  
  def validate_cumulative_and_new_registered_males
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Registered Males  (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered male'],
              self.cohort_object['Newly registered male']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
  
  def validate_cumulative_and_new_non_pregnant_females
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate non pregnant females  (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered women (non-pregnant)'],
              self.cohort_object['Newly registered women (non-pregnant)']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
  
  def validate_cumulative_and_new_pregnant_females
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate pregnant females  (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered women (pregnant)'],
              self.cohort_object['Newly registered women (pregnant)']
                ]

    return self.feed_values(validation_rule.expr, values)
  end
  
  def validate_cumulative_and_new_children_below_24_months
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate children below 24 months (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered infants'],
              self.cohort_object['Newly registered infants']
                ]

    return self.feed_values(validation_rule.expr, values)
  end 
  
  def validate_cumulative_and_new_children_between_24_months_and_14_years
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate children between 24 months and 14 years (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered children'],
              self.cohort_object['Newly registered children']
                ]

    return self.feed_values(validation_rule.expr, values)
  end 
  
  def validate_cumulative_and_new_adults
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate adults (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered adults'],
              self.cohort_object['Newly registered adults']
                ]

    return self.feed_values(validation_rule.expr, values)
  end 
  
  def validate_cumulative_and_new_unknown_age
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate unknown age (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_type_id(1)
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Unknown age'],
              self.cohort_object['Newly Unknown age']
                ]

    return self.feed_values(validation_rule.expr, values)
  end 

  def validate_kaposis_sarcoma_less_than_total
		#This method checks that cases of kaposis sarcoma are less than total registered in quarter	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_desc('Patients with kaposis sarcoma')
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Kaposis Sarcoma'],
				 			self.cohort_object['Newly total registered']]			 					
		return self.feed_values(validation_rule.expr, values)		
	end
	
	def validate_cumulative_kaposis_sarcoma_less_than_total
		#This method checks that all cases of kaposis sarcoma are less than cumulative total registered	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_desc('Patients with kaposis sarcoma')
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Total Kaposis Sarcoma'],
				 			self.cohort_object['Total registered']]			 					
		return self.feed_values(validation_rule.expr, values)		
	end
	
	def validate_cumulative_outcomes_less_than_or_equal_to_total_registered
		#This method checks that outcome totals dont exceed total registered	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_desc("Died total, Total alive and on ART, Defaulted (more than 2 months overdue after expected to have run out of ARVs), Stopped taking ARVs (clinician or patient own decision last known alive), Transfered out, and Unknown outcome should add up to Total registe")
		
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Total registered'],
				 			self.cohort_object['Died total'],
				 			self.cohort_object['Total alive and on ART'],
				 			self.cohort_object['Defaulted'],
				 			self.cohort_object['Stopped taking ARVs'],
				 			self.cohort_object['Transferred out'],
				 			self.cohort_object['Unknown outcomes']
				 			]			 					
		return self.feed_values(validation_rule.expr, values)		
	end	

  def validate_adherence_sum_zero_to_six_and_seven_plus_needs_to_equal_total_alive_and_on_art
    validation_rule = ValidationRule.find_by_desc("Patients with 0-6 doses missed at their last visit(before end of quarter evaluated), and Patients with 7+ doses missed at their last visit(before end of quarter evaluated) should add up to Total alive and on ART")
    return nil if validation_rule.blank?
    values = [self.cohort_object['Total alive and on ART'],
				 			self.cohort_object['Patients with 0 - 6 doses missed at their last visit'],
				 			self.cohort_object['Patients with 7+ doses missed at their last visit']
				 			]
		return self.feed_values(validation_rule.expr, values)
  end

  def validate_sum_of_stage_defining_conditions_needs_to_equal_total_registered
     validation_rule = ValidationRule.find_by_desc("[CUMULATIVE] No TB, TB within the last 2 years, Current episode of TB, and Kaposis Sarcoma should add up to Total registered")
     values = [self.cohort_object['Total registered'],
				 			self.cohort_object['Total No TB'],
				 			self.cohort_object['Total TB within the last 2 years'],
				 			self.cohort_object['Total Current episode of TB'],
				 			self.cohort_object['Total Kaposis Sarcoma']
				 			]
		return self.feed_values(validation_rule.expr, values)		
  end
end

