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
      find(:all, :conditions => ["encounter_datetime BETWEEN ? AND ?", 
           encounter_date.to_date.strftime('%Y-%m-%d 00:00:00'), 
           encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')
      ]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end

  def after_create
    if Location.current_location.name == "Martin Preuss Centre" 
      person = self.person
      patient_bin = PatientService.get_patient(person)
      date_created = person.date_created.strftime('%Y-%m-%d %H:%M:%S') rescue Time.now().strftime('%Y-%m-%d %H:%M:%S')
      first_name = patient_bin.name.split(" ")[0] rescue nil
      last_name = patient_bin.name.split(" ")[1] rescue nil

      ActiveRecord::Base.connection.execute <<EOF                             
INSERT INTO openmrs_demographx.patient (patient_id,gender,birthdate,creator,date_created,date_changed)
VALUES(#{patient_bin.patient_id},"#{patient_bin.sex}","#{person.birthdate}",#{person.creator},'#{date_changed}','#{date_created}');
EOF

      ActiveRecord::Base.connection.execute <<EOF                             
INSERT INTO openmrs_demographx.patient_name (patient_id,given_name,family_name,creator,date_created,date_changed)
VALUES(#{patient_bin.patient_id},"#{first_name}","#{last_name}",#{person.creator},'#{date_created}','#{date_created}');
EOF

      ActiveRecord::Base.connection.execute <<EOF                             
INSERT INTO openmrs_demographx.patient_identifier (patient_id,identifier,identifier_type,creator,date_created,date_changed)
VALUES(#{patient_bin.patient_id},"#{patient_bin.national_id}",1,#{person.creator},'#{date_created}','#{date_created}');
EOF
    end rescue nil
  end

end
