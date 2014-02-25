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
		  
end

