class CreatePatientDefaultedDates < ActiveRecord::Migration
  def self.up
    create_table :patient_defaulted_dates do |t|
      t.integer :patient_id                              
      t.integer :order_id
      t.integer :drug_id
      t.float   :equivalent_daily_dose
      t.integer :amount_dispensed
      t.integer :quantity_given
      t.date    :start_date
      t.date    :end_date
      t.date    :defaulted_date

      t.date :date_created, :default => Date.today
    end
  end

  def self.down
    drop_table :patient_defaulted_dates
  end
end
