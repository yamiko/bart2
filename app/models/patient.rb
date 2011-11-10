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
