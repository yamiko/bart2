	class LabTestType < ActiveRecord::Base
	  set_table_name "codes_TestType"
    
    def self.test_name(test_type)
      return LabTestType.find(:all,:conditions=>["TESTTYPE=?",test_type.to_i]).first.TestName rescue nil
    end 
    
    def self.test_type_by_name(test_type)
      panel_id = LabTestType.find(:first,:conditions=>["TestName=?",test_type]).Panel_ID rescue nil
      return LabPanel.test_name(panel_id).to_s rescue nil
    end 

    def self.available_test
      self.find(:all).map{|test|test.TestName}
    end
  end  
