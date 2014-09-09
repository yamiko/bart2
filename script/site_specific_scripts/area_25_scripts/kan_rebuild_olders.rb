#script to rebuild the obs table

def init
  if ARGV[0].blank? or ARGV[1].blank? 
     puts "Usage: "
     puts 'script/runner script start_date end_date'
     puts 'start date format : "YYYY-mm-dd"'
     puts 'end date format   : "YYYY-mm-dd"'
     puts 'Rebuld terminated  .........'
     return
  end
  get_orders(ARGV[0], ARGV[1])
end

def get_orders(start_date, end_date)
  # date = date.to_date.strftime('%Y-%m-%d')
   ordered = Observation.find_by_sql("SELECT * FROM obs
                    WHERE order_id IS NOT NULL AND DATE(obs_datetime) >= '#{start_date.to_date}'
                     AND DATE(obs_datetime) <= '#{end_date.to_date}'
                    AND voided = 0 ORDER BY order_id ASC")
   puts "Orders will be built from #{start_date} to #{ordered.last.obs_datetime.strftime('%Y-%m-%d')}"
   x = 0
   ordered.each{|order|
  
      related = Order.find_by_sql("
        SELECT * FROM orders WHERE order_id = #{order.order_id}")
      if related.blank?
        x += 1
        drug_order = DrugOrder.find(order.order_id)
        quantity = drug_order.quantity
        dose = drug_order.dose
        daily = drug_order.equivalent_daily_dose
        duration = quantity / (dose * daily)
        concept_id = drug_order.drug.concept_id
        orderer = order.creator
        encounter_id = order.encounter_id
        start_date = order.obs_datetime.to_date
        auto_expire_date = start_date + duration.to_i.days
        patient_id = order.person_id
        creator = order.creator
        voided = 0
        uuid =  ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']

        new_order  = Order.create(
        :order_id => order.order_id,
        :order_type_id => 1,
        :concept_id => concept_id,
        :orderer => orderer,
        :patient_id => patient_id,
        :start_date => start_date,
        :auto_expire_date => auto_expire_date,
        :encounter_id => encounter_id,
        :creator => creator,
        :voided => voided,
        :uuid => uuid)
        puts "#{x} : #{order.order_id} with concept #{concept_id} to build"
        
      end
   }
end

def check_arvs(order)
    arvs = RegimenDrugOrder.find_by_sql("SELECT * FROM regimen_drug_order
                WHERE drug_inventory_id = #{order.drug.drug_id}")
    return arvs
end



init