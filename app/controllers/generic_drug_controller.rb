class GenericDrugController < ApplicationController

  def name
  drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
              'Atazanavir', 'Ritonavir', 'Abacavir', '(',')'
    ]
    regimen = Regimen.find(:all,:order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders)#.to_yaml
    regimen = regimen.map do |r|
			[r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
		end
    @names = []
    regimen.uniq.each { |r|
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      @names << r
    }
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @names += other
    # regimens = regimens.map{|d|
    # concept_name = (d.concept.concept_names.typed("SHORT").first ||	d.concept.concept_names.typed("FULLY_SPECIFIED").first).name
    # if d.regimen_index.blank?
    #	["#{concept_name}", d.concept_id, d.regimen_index.to_i]
		#	else
		#		["#{d.regimen_index} - #{concept_name}", d.concept_id, d.regimen_index.to_i]
		#	end
		#}.sort_by{| r | r[2]}.uniq

    #@names = Drug.find(:all,:conditions =>["name LIKE ?","%" + params[:search_string] + "%"]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def list_stock
    @drugs = session[:"#{params[:id]}"].sort
    render :layout => 'report'
  end

  def regimen_name_map
  drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
              'Atazanavir', 'Ritonavir', 'Abacavir', '(',')', 'Lopinavir', 'Efavirenz', 'Isoniazid'
    ]
  more_regimen = ["LPV/r (Lopinavir and Ritonavir syrup)", "LPV/r (Lopinavir and Ritonavir 200/50mg tablet)","LPV/r (Lopinavir and Ritonavir 100/25mg tablet)","EFV (Efavirenz 600mg tablet)", "EFV (Efavirenz 200mg tablet)"]
  other = [ "Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    regimen = Regimen.find(:all,:order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders)#.to_yaml
    regimen = regimen.map do |r|
			[r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
		end
    
    @names = {}
    regimen.uniq.each { |r|
      fullname = r
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    more_regimen.each{|r|
     fullname = r
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    other.each{|drug|
      @names[drug] = drug
    }
    return @names

  end

  def add_controllers
    drugs = params[:drug].split(",")
    drugs.each {|drug|
      if drug != ""
        
      end
    }
  end

  def verified_stock
    @delivery_date = params[:observations].first["value_datetime"]
     @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @drugs += other
    @formatted = preformat_regimen
    @drug_short_names = regimen_name_map
    
  end
  
  def delivery

    @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @drugs += other
  end

  def calculate_dispensed
   
    drug_id = Drug.find_by_name(params[:drug]).id
     #raise params[:name].to_yaml
    current_stock = Pharmacy.current_stock_as_from(drug_id , Pharmacy.first_delivery_date(drug_id),params[:start_date].to_date)
     
      expiry = 0
      Pharmacy.currently_expiring_drugs(params[:start_date].to_date, drug_id).each {|stock|
        #raise stock[1].to_yaml
        expiry += stock[1]["delivered_stock"]

      }
      if current_stock > 0 and current_stock <= expiry
          expiry = current_stock
      elsif current_stock > expiry
          expiry = expiry 
      else
         expiry = 0
      end
      # raise expiry.to_yaml
    render :text => expiry
  end

  def create_stock
    params[:drug].each{ |delivered|

      delivery_date = params['delivery date'].to_date
      drug_id = Drug.find_by_name(delivered[:name]).id



      expiry_date = delivered["#{delivered[:name]}"]['expiry_date'].to_date
    
      number_of_tins = delivered["#{delivered[:name]}"]['tins'].to_f
      number_of_pills_per_tin = delivered["#{delivered[:name]}"]['pills'].to_f
      number_of_pills = (number_of_tins * number_of_pills_per_tin)
      barcode = params[:identifier]
      Pharmacy.new_delivery(drug_id,number_of_pills,delivery_date,nil,expiry_date,barcode)
    }
    #add a notice
    #flash[:notice] = "#{params[:drug_name]} successfully entered"
    redirect_to "/clinic"   # /management"
  end

  def edit_stock
    if request.method == :post
      obs = params[:observations]
      edit_reason = obs[0]['value_coded_or_text']
      encounter_datetime = obs[1]['value_datetime']
      if ! params[:drug_names].blank?
         name = params[:drug_names]
      else
         name = params[:drug_name]
      end
      drug_id = Drug.find_by_name(name).id
      pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
      date = encounter_datetime || Date.today 

      if edit_reason == 'Receipts from other clinics'
        expiry_date = obs[2]['value_datetime'].to_date
        Pharmacy.new_delivery(drug_id,pills,date,nil,expiry_date,edit_reason)
      else
        Pharmacy.drug_dispensed_stock_adjustment(drug_id,pills,date,edit_reason)
      end
      #flash[:notice] = "#{params[:drug_name]} successfully edited"
      redirect_to "/clinic"   # /management"
    else 
      @drugs =  Regimen.find_by_sql(
        "select distinct(d.name) from regimen r
                      inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
                      inner join drug d on d.drug_id = rd.drug_inventory_id
                      where r.regimen_index is not null
                      and r.regimen_index != 0
        ").collect{|drug| drug.name}.compact.sort.uniq rescue []
      other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
      @drugs += other
      ids = Pharmacy.active.find(:all).collect{|p|p.drug_id} rescue []
      @names = Drug.find(:all,:conditions =>["drug_id IN (?)", ids]).collect{|drug| drug.name}

    end
  end

  def set_quantity
    
  end

  def verification
    obs = params[:observations]
    edit_reason = obs[0]['value_coded_or_text']
    encounter_datetime = obs[0]['value_datetime']
    drug_id = Drug.find_by_name(params[:drug_name]).id
    pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
    date = encounter_datetime || Date.today
    Pharmacy.verified_stock(drug_id,date,pills) 
    redirect_to "/clinic"   # /management"
  end

  def months_of_stock
    @start_date = params[:start_date].to_date
    @end_date   = params[:end_date].to_date
    
    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)
    @month_on_stock = 1 if @month_on_stock == 0
    
    @stocks = []
    all_drugs = regimen_name_map
    @formatted = preformat_regimen
    @formatted.each{|drug_id|
      
      drug = Drug.find_by_name("#{drug_id}")
      expected = (Pharmacy.current_stock_as_from(drug.id, @start_date, @end_date) / 60).round
      confirmed_closing = (Pharmacy.verify_closing_stock_count(drug.id,params[:start_date], params[:end_date]) / 60).round
      
      dispensed = (Pharmacy.dispensed_drugs_since(drug.id, params[:start_date], params[:end_date]) / 60).round
      consumption = (dispensed.to_i /  @month_on_stock ) rescue 0
      @months_of_stock = (confirmed_closing.to_i / consumption.to_i) rescue 0
      @months_of_stock = 0 if @months_of_stock.blank?
      
      @months_of_stock = 9 if @months_of_stock > 9
      drug_name = all_drugs["#{drug.name}"] rescue drug.name
      name = "<span>#{drug_name}  <b>#{expected}</b></span>"
      name = "<span>#{drug_name}  <b>#{expected}  No consumption</b></span>" if @months_of_stock == 0
      @stocks << [ name, (@months_of_stock.to_i rescue 0)]
     }

    @stocks = @stocks.to_json
    render :partial => "months_of_stock" and return
  end

  def stoke_movement
    if params[:report_type] == "Stock Movement"
    drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
              'Atazanavir', 'Ritonavir', 'Abacavir', '(',')'
    ]
    regimen = Regimen.find(:all,:order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders)#.to_yaml
    regimen = regimen.map do |r|
			[r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
		end
    regimen += ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    regimen.uniq.each { |r|
      t = r
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
       if r.downcase == params[:drug_name].to_s.downcase
         params[:drug_name] = t
       end
      }
      
    }
    else
      @drugs = regimen_name_map
    end
  
    obs = params[:observations]
    params[:start_date] =  obs[0]['value_datetime']
    params[:end_date] =  obs[1]['value_datetime']
    @start_date = params[:start_date].to_date
    @end_date   = params[:end_date].to_date

    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)

    @month_on_stock = 1 if @month_on_stock == 0
    if params[:report_type] == "Stock Movement"
        params[:drug_id] = Drug.find_by_name(params[:drug_name]).id
        @drug = Drug.find(params[:drug_id]).name
    end
    
    render :layout => false
  end

  def stock_report
    @start_date,@end_date = Report.generate_cohort_date_range(params[:quarter])
    @current_location_name = Location.current_health_center.name rescue ''
    if @start_date.blank?
        @start_date = params[:start_date].to_date if not params[:start_date].blank?
        @end_date = params[:end_date].to_date rescue params[:delivery_date].to_date
    end
   
    #TODO
     current_stock = preformat_regimen
    drugs = regimen_name_map
    @drug_array = drugs
    @formatted = current_stock
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    #new_deliveries = Pharmacy.active.find(:all,
    #  :conditions =>["pharmacy_encounter_type=?",encounter_type],
    #  :order => "encounter_date DESC,date_created DESC")

    new_deliveries = Pharmacy.find_by_sql("
                     SELECT distinct(drug_id) FROM pharmacy_obs")

    if @start_date.blank?
        encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
        @start_date = Pharmacy.find_by_sql("SELECT * FROM pharmacy_obs
                                     WHERE pharmacy_encounter_type = #{encounter_type}
                                     AND DATE(encounter_date) < '#{@end_date}' AND vaue_text = 'SUPERVISION'
                                    ").first.encounter_date rescue []
        if @start_date.blank?
           @start_date = @end_date - 3.months
           @start_date = @start_date.beginning_of_month
        end
    end
    @days = @end_date - @start_date
    
    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)

    @month_on_stock = 1 if @month_on_stock == 0
    
    #current_stock = {}
    new_deliveries.each{|delivery|
      current_stock[delivery.drug_id] = delivery if current_stock[delivery.drug_id].blank?
    }

    @stock = {}
     encounter_type_id = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    current_stock.each{|delivery|
      drug = Drug.find_by_name("#{delivery}")
      first_date = Pharmacy.active.find(:first,:conditions =>["drug_id =?",
          drug.id],:order => "encounter_date").encounter_date.to_date rescue nil
      next if first_date.blank?
      next if first_date > @end_date

      start_date = @start_date
      end_date = @end_date
      
     # drug = Drug.find(delivery.drug_id)

      drug_name = drugs["#{drug.name}"]
      if drug_name.blank?
        drug_name = drug.name
      end

      end_pharmacy_id = Pharmacy.active.find(:first,
        :conditions =>["pharmacy_encounter_type = ? AND  encounter_date > ? AND encounter_date <= ?
                        AND drug_id = ? AND value_text = 'Supervision'",
        encounter_type_id, @start_date, @end_date, drug.id],
        :order =>'encounter_date DESC,date_created DESC').id rescue 0
     start_pharmacy_id = Pharmacy.active.find(:first,
      :conditions =>["pharmacy_encounter_type = ? AND encounter_date <= ? AND drug_id = ? AND value_text = 'Supervision'",
      encounter_type_id, start_date, drug.id],
      :order =>'encounter_date DESC,date_created DESC').id rescue 0

      #Pharmacy.verify_stock_count(drug.id,start_date,end_date)
      @stock[drug_name] = {"confirmed_closing" => 0,"dispensed" => 0,"current_stock" => 0 ,
        "confirmed_opening" => 0, "start_date" => start_date , "end_date" => end_date,
        "relocated" => 0, "receipts" => 0,"expected" => 0 ,"drug_id" => drug.id }
      @stock[drug_name]["dispensed"] = Pharmacy.dispensed_drugs_since(drug.id,start_date,end_date)
      @stock[drug_name]["confirmed_opening"] = Pharmacy.verify_stock_count(drug.id,start_date,start_date)
      @stock[drug_name]["confirmed_closing"] = Pharmacy.verify_closing_stock_count(drug.id,start_date,end_date)
      @stock[drug_name]["current_stock"] = Pharmacy.current_stock_as_from(drug.id,start_date,end_date)
      @stock[drug_name]["relocated"] = Pharmacy.relocated(drug.id,start_date,end_date)
      @stock[drug_name]["receipts"] = Pharmacy.receipts(drug.id,start_date,end_date)
      @stock[drug_name]["expected"] = Pharmacy.expected(drug.id,start_date,end_date)
      @stock[drug_name]["end_pharmacy_id"] = end_pharmacy_id
      @stock[drug_name]["start_pharmacy_id"] = start_pharmacy_id
    }
   
    #@stock.sort{|a,b| (a[0] == b[0]) ? a[1] <=> b[1] : a[0] <=> b[0] }
  end

  def current_stock
    drug = Drug.find_by_name(params[:drug])
    start_date = Date.today
    end_date =  start_date + 30.days
    expected = Pharmacy.expected(drug.id, start_date,end_date)
    render :text => (expected.to_json)
  end

  def stock_chart
    encounter_type = PharmacyEncounterType.find_by_name("Tins currently in stock").id
    #new_deliveries = Pharmacy.active.find(:first,
    # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], params[:end_date] ],
    #  :order => "encounter_date DESC,date_created DESC")
    
    @stocks = []
    current_stock = {}
    month_difference = (params[:end_date].to_date.year * 12 + params[:end_date].to_date.month) - (params[:start_date].to_date.year * 12 + params[:start_date].to_date.month)
    n = params[:end_date].to_date
    # raise Pharmacy.expected(params[:drug_id], params[:start_date], params[:end_date]).to_yaml
    if month_difference <= 1
      while n >= params[:start_date].to_date
        new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], n)
        # new_deliveries = Pharmacy.active.find(:first,
        # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], n ],
        # :order => "encounter_date DESC,date_created DESC")
        current_stock[n] = (new_deliveries / 60).round rescue 0
        n = n - 1.days
      end
    elsif month_difference > 1 and month_difference <= 12
      while n >= params[:start_date].to_date
        new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], n)
        # new_deliveries = Pharmacy.active.find(:first,
        # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], n ],
        # :order => "encounter_date DESC,date_created DESC")
        current_stock[n] = (new_deliveries / 60).round rescue 0
        n = n - 1.months

      end
    else
      while n >= params[:start_date].to_date
        new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], n)
        #new_deliveries = Pharmacy.active.find(:first,
        #:conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], n ],
        #:order => "encounter_date DESC,date_created DESC")
        current_stock[n] = (new_deliveries / 60).round rescue 0
        n = n - 1.years
      end
    end
    
    #new_deliveries.each{|delivery|
    #  current_stock[delivery.encounter_date] = (delivery.value_numeric / 60 ).round #if current_stock[delivery.drug_id].blank?
    # }

    (current_stock || {}).sort{|a,b|a[0].to_date <=> b[0].to_date}.each do |date,weight|
      @stocks << [date.to_date.strftime('%d.%b.%y') , weight]
    end
    @stocks = @stocks.to_json
    render :partial => "stoke_chart" and return
  end
  def preformat_regimen
   formatted = [ "ABC/3TC (Abacavir and Lamivudine 60/30mg tablet)",
     "AZT/3TC (Zidovudine and Lamivudine 60/30 tablet)",
     "AZT/3TC (Zidovudine and Lamivudine 300/150mg)",
     "AZT/3TC/NVP (60/30/50mg tablet)",
     "AZT/3TC/NVP (300/150/200mg tablet)",
     "d4T/3TC (Stavudine Lamivudine 6/30mg tablet)",
     "d4T/3TC (Stavudine Lamivudine 30/150 tablet)",
     "Triomune baby (d4T/3TC/NVP 6/30/50mg tablet)",
     "d4T/3TC/NVP (30/150/200mg tablet)",
     "EFV (Efavirenz 200mg tablet)",
     "EFV (Efavirenz 600mg tablet)",
     "LPV/r (Lopinavir and Ritonavir 100/25mg tablet)",
     "LPV/r (Lopinavir and Ritonavir 200/50mg tablet)",
     "LPV/r (Lopinavir and Ritonavir syrup)",
     "ATV/r (Atazanavir 300mg/Ritonavir 100mg)",
     "NVP (Nevirapine 200 mg tablet)",
     "TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet","TDF/3TC/EFV (300/300/600mg tablet)",
     "Cotrimoxazole (480mg tablet)",
     "Cotrimoxazole (960mg)", "INH or H (Isoniazid 100mg tablet)", "INH or H (Isoniazid 300mg tablet)"]
   return formatted
  end
  def date_select
    @goto = params[:goto]
    @goto = 'stock_report' if @goto.blank?
    @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @drugs += other
  end

  def stock_movement_menu
   drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
              'Atazanavir', 'Ritonavir', 'Abacavir', '(',')'
    ]
    @names = Regimen.find(:all,:order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders)#.to_yaml
    @names = @names.map do |r|
			[r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
		end
    new_list = []
    @names.uniq.each { |r|
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      new_list << r
    }
    #raise new_list.to_yaml
  end

  def print_barcode
    if request.post?
      print_and_redirect("/drug/print?drug_id=#{params[:drug_id]}&quantity=#{params[:pill_count]}", "/drug/print_barcode")
    else
      @drugs = Drug.find(:all,:conditions =>["name IS NOT NULL"])
    end
  end
  
  def print
    pill_count = params[:quantity]
    drug = Drug.find(params[:drug_id])
    drug_name = drug.name
    drug_name1=""
    drug_name2=""
    drug_quantity = pill_count
    drug_barcode = "#{drug.id}-#{drug_quantity}"
    drug_string_length =drug_name.length

    if drug_name.length > 27
      drug_name1 = drug_name[0..25]
      drug_name2 = drug_name[26..-1]
    end

    if drug_string_length <= 27
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 80, 0, 2, 2, 2,false)
      label.draw_barcode(40, 130, 0, 1, 5, 15, 120,true, "#{drug_barcode}")
    else
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name1}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("#{drug_name2}", 40, 80, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 130, 0, 2, 2, 2,false)
      label.draw_barcode(40, 180, 0, 1, 5, 15, 100,true, "#{drug_barcode}")
    end
    send_data(label.print(1),:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{drug_barcode}.lbl", :disposition => "inline")
  end

  def expiring
    @logo = CoreService.get_global_property_value('logo') rescue ''
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @expiring_drugs = Pharmacy.expiring_drugs(@start_date,@end_date)
    render :layout => "menu"
  end
  
  def removed_from_shelves
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @drugs_removed = Pharmacy.removed_from_shelves(@start_date,@end_date)
    render :layout => "menu"
  end

  def available_name    
    ids = Pharmacy.active.find(:all).collect{|p|p.drug_id} rescue []
    @names = Drug.find(:all,:conditions =>["name LIKE ? AND drug_id IN (?)","%" + 
          params[:search_string] + "%", ids]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def stock_report_edit

    if request.post?
      unless params[:obs].blank?
       
        params[:obs].each{|obs|
          drug_id = Drug.find_by_name(obs[0]).id rescue []
          next if drug_id.blank?
          tins = obs[1]["amount"].to_i
          expiry_date = nil
          if tins != 0
            date_value = obs[1]['date'].split("/")
            year = date_value[1]
            month = date_value[0]
            expiry_date = "#{year}-#{month}-#{01}"
            expiring_units = obs[1]['expire_amount']
          end
          
          pills = tins * 60
          
          Pharmacy.verified_stock(drug_id, params[:delivery_date],pills, expiry_date, expiring_units, params[:type])
          
        }
        
      else
        obs = params[:observations]
        edit_reason = obs[0]['value_coded_or_text'] rescue nil
        encounter_datetime = params[:encounter_date]
        drug_id = params[:drug_id]
        pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
        date = encounter_datetime || Date.today

        unless edit_reason.blank?
          Pharmacy.drug_dispensed_stock_adjustment(drug_id,pills,date,edit_reason)
        else

         pharmacy = Pharmacy.find(drug_id)
         pharmacy.value_numeric = pills
         pharmacy.save!

        end
      end
      redirect_to :action => 'stock_report', :start_date => params[:start_date],                                  
        :end_date => params[:end_date], :delivery_date => params[:delivery_date]
    else
      @edit_reason = params[:edit_reason]
      @drug_id = params[:drug_id]
      @encounter_date = params[:date]
      @max_date = params[:max_date]
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end
  end

end
