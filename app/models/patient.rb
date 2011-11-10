class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do 
    def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["DATE(encounter_datetime) = DATE(?)", encounter_date]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end
=begin
  def summary #
    #    verbiage << "Last seen #{visits.recent(1)}"
    verbiage = []
    verbiage << patient_programs.map{|prog| "Started #{prog.program.name.humanize} #{prog.date_enrolled.strftime('%b-%Y')}" rescue nil }
    verbiage << orders.unfinished.prescriptions.map{|presc| presc.to_s}
    verbiage.flatten.compact.join(', ') 
  end
=end

	  def get_identifier(type = 'National id')
    identifier_type = PatientIdentifierType.find_by_name(type)
    return if identifier_type.blank?
    identifiers = self.patient_identifiers.find_all_by_identifier_type(identifier_type.id)
    return if identifiers.blank?
    identifiers.map{|i|i.identifier}[0] rescue nil
  end

=begin
  #This method is not being called anywhere in the application
  def last_art_visit_before(date = Date.today)
    art_encounters = ['ART_INITIAL','HIV RECEPTION','VITALS','HIV STAGING','ART VISIT','ART ADHERENCE','TREATMENT','DISPENSING']
    art_encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",art_encounters]).map{|e|e.encounter_type_id}
    Encounter.find(:first,
      :conditions => ["DATE(encounter_datetime) < ? AND patient_id = ? AND encounter_type IN (?)",date,
        self.id,art_encounter_type_ids],
      :order => 'encounter_datetime DESC').encounter_datetime.to_date rescue nil
  end
=end

<<<<<<< HEAD
  def set_new_filing_number
    ActiveRecord::Base.transaction do
      global_property_value = GlobalProperty.find_by_property("filing.number.limit").property_value rescue '10'

      filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing number")
      archive_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")

      next_filing_number = PatientIdentifier.next_filing_number('Filing number')
      if (next_filing_number[5..-1].to_i >= global_property_value.to_i)
        encounter_type_name = ['REGISTRATION','VITALS','ART_INITIAL','ART VISIT',
          'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
        encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id} 
    
        all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ?",
            filing_number_identifier_type.id],:group=>"patient_id")
        patient_ids = all_filing_numbers.collect{|i|i.patient_id}
        patient_to_be_archived = Encounter.find_by_sql(["
          SELECT patient_id, MAX(encounter_datetime) AS last_encounter_id
          FROM encounter 
          WHERE patient_id IN (?)
          AND encounter_type IN (?) 
          GROUP BY patient_id
          ORDER BY last_encounter_id
          LIMIT 1",patient_ids,encounter_type_ids]).first.patient rescue nil

        if patient_to_be_archived.blank?
          patient_to_be_archived = PatientIdentifier.find(:last,:conditions =>["identifier_type = ?",
              filing_number_identifier_type.id],
            :group=>"patient_id",:order => "identifier DESC").patient rescue nil
        end
      end

      if self.get_identifier('Archived filing number')
        #voids the record- if patient has a dormant filing number
        current_archive_filing_numbers = self.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == archive_identifier_type.id and identifier.voided
        }.compact
        current_archive_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "patient assign new active filing number"
          filing_number.voided_by = User.current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      end
     
      unless patient_to_be_archived.blank?
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = self.id
        filing_number.identifier = patient_to_be_archived.get_identifier('Filing Number')
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save

        current_active_filing_numbers = patient_to_be_archived.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == filing_number_identifier_type.id and not identifier.voided
        }.compact
        current_active_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "Archived - filing number given to:#{self.id}"
          filing_number.voided_by = User.current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      else
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = self.id
        filing_number.identifier = next_filing_number
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save
      end 
      true
    end
  end
=======
  
  

  


>>>>>>> 72fb65858d9e08b71cf1a02944c7519df7b96735

  def id_identifiers
    identifier_type = ["Legacy Pediatric id","National id","Legacy National id"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_type]
    ).collect{| type |type.id }
    
    PatientIdentifier.find(:all,
      :conditions=>["patient_id=? AND identifier_type IN (?)",
        self.id,identifier_types]).collect{| i | i.identifier }
  end

  def eid_number
    eid_number_id = PatientIdentifierType.find_by_name('EID Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, eid_number_id).identifier rescue nil
  end

  def filing_number
    filing_number = PatientIdentifierType.find_by_name('Filing Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, filing_number).identifier rescue nil
  end

  def pre_art_number
    pre_art_number_id = PatientIdentifierType.find_by_name('Pre ART Number (Old format)').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, pre_art_number_id).identifier rescue nil
  end
  
=begin # could not find where it is being used DFFI
  def is_first_visit?
    clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",
                          'ART ADHERENCE','DISPENSING','ART_INITIAL', "LAB ORDERS",
                          "LAB RESULTS","HIV RECEPTION","SPUTUM SUBMISSION",
                          "TB RECEPTION","TB REGISTRATION","TB TREATMENT",
                          "TB_FOLLOWUP"
                          ]
    current_date = Time.now.strftime("%d-%b-%Y")

    clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
    first_encounter_date = self.encounters.find(:first,
      :order => 'encounter_datetime',
      :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Unknown'

    return true if first_encounter_date == 'Unknown'
    return true if current_date == first_encounter_date
    return false if current_date > first_encounter_date

  end
=end
 
=begin # could not find a place where the method below is being used, therefore just disabled it
# for further investigation
  def sputum_results_given
   given_results = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("GIVE LAB RESULTS").id,self.id]).observations.map{|o| o if self.recent_sputum_orders.collect{|observation| observation.accession_number}.include?(o.accession_number)} rescue []
  end
=end
end
