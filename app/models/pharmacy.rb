class Pharmacy < ActiveRecord::Base
  set_table_name "pharmacy_obs"
  set_primary_key "pharmacy_module_id"
  include Openmrs

  named_scope :active, :conditions => ['voided = 0']
=begin
  def after_save
    super
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    if self.pharmacy_encounter_type == encounter_type
     Pharmacy.reset(self.drug_id)
    end
  end
=end

  def self.voided_stock_adjustment(order)
  end

  def self.dispensed_stock_adjustment(encounter)
  end

  def self.drug_dispensed_stock_adjustment(drug_id,quantity,encounter_date,reason = nil)
    encounter_type = PharmacyEncounterType.find_by_name("Tins removed").id if encounter_type.blank?
    encounter =  self.new()
    encounter.pharmacy_encounter_type = encounter_type
    encounter.drug_id = drug_id
    encounter.encounter_date = encounter_date
    encounter.value_numeric = quantity.to_f
    encounter.value_text = reason unless reason.blank?
    encounter.save
  end

  def self.reset(drug_id=nil,current_number_of_pills=0)
  end
     
  def self.date_ranges(date)    
    current_range =[]
    current_range << Report.cohort_range(date).last
    end_date = Report.cohort_range(Date.today).last
    while current_range.last < end_date
      current_range << Report.cohort_range(current_range.last + 1.day).last
    end  
    current_range[1..-1] rescue nil
  end

  def Pharmacy.dispensed_drugs_since(drug_id,date,end_date = Date.today)
  end

  def Pharmacy.dispensed_drugs_to_date(drug_id)
  end

  def Pharmacy.prescribed_drugs_since(drug_id,start_date,end_date = Date.today)
  end

  def self.current_stock(drug_id)
  end

  def self.current_stock_as_from(drug_id,start_date=Date.today,end_date=Date.today)
  end


  def self.new_delivery(drug_id,pills,date = Date.today,encounter_type = nil,expiry_date = nil)
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id if encounter_type.blank?
    delivery =  self.new()
    delivery.pharmacy_encounter_type = encounter_type
    delivery.drug_id = drug_id
    delivery.encounter_date = date
    delivery.expiry_date = expiry_date unless expiry_date.blank?
    delivery.value_numeric = pills.to_f

    if expiry_date
      if expiry_date.to_date < Date.today
        delivery.voided = 1
        return delivery.save
      end  
    end
    delivery.save
  end

  def Pharmacy.total_delivered(drug_id,start_date=nil,end_date=nil)
  end

  def self.first_delivery_date(drug_id)
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    Pharmacy.active.find(:first,:conditions => ["drug_id=? AND pharmacy_encounter_type=?",drug_id,encounter_type],
    :order => "encounter_date ASC,date_created ASC").encounter_date rescue nil
  end

  def self.remove_stock(encounter_id)
  end

end
