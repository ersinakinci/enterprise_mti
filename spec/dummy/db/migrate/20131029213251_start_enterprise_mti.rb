class StartEnterpriseMti < ActiveRecord::Migration
  def up
    enterprise_mti_up superclass_table: 'superthings', subclass_tables: ['subthing_ones', 'subthing_twos']
  end
  
  def down
    enterprise_mti_down superclass_table: 'superthings', subclass_tables: ['subthing_ones', 'subthing_twos']
  end
end
