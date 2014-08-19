class CreateDrugOrderBarcodes < ActiveRecord::Migration
  def self.up
    create_table :drug_order_barcodes, :primary_key => :drug_order_barcode_id do |t|
      t.integer :drug_id
      t.integer :tabs
      t.timestamps
    end
  end

  def self.down
    drop_table :drug_order_barcodes
  end
end
