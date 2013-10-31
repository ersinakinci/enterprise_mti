require 'spec_helper'
require 'helpers/migration_spec_helpers.rb'

describe EnterpriseMti::Migration do
  include MigrationHelpers
  
  SUPPORTED_DATABASES = ['postgresql']
  DATABASE_TYPE = Rails.configuration.database_configuration[Rails.env]['adapter']

  context 'the Rails app has a database set up' do
    
    it 'is of a supported database type' do
      expect(SUPPORTED_DATABASES.include? DATABASE_TYPE).to be_true
    end
  end

  if SUPPORTED_DATABASES.include? DATABASE_TYPE
    
    context 'having migrated superclass, subclasses, and MTI,' do
    
      before :all do
        migrate_all
      end
    
      let(:superclass_table) { 'superthings' }
    
      context 'and having rolled back MTI,' do
      
        before :all do
          StartEnterpriseMti.migrate :down
        end
      
        context 'the superclass table' do
          subject(:superclass_columns) { columns(superclass_table) }
        
          it 'does not have a column for the first subclass' do
            expect(superclass_columns.include? 'subthing_ones_id').not_to be_true
          end
        
          it 'does not have a column for the second subclass' do
            expect(superclass_columns.include? 'subthing_twos_id').not_to be_true
          end
        
          subject(:superclass_constraints) { constraints(superclass_table) }
        
          it 'does not have an XOR constraint' do
            expect(superclass_constraints.include? 'superthings_xor').not_to be_true
          end
        end
      
        after :all do
          StartEnterpriseMti.migrate :up
        end
      end
    
      context 'the superclass table' do
      
        subject(:superclass_columns) { columns(superclass_table) }
      
        it 'has a column for the first subclass' do
          expect(superclass_columns.include? 'subthing_ones_id').to be_true
        end
      
        it 'has a column for the second subclass' do
          expect(superclass_columns.include? 'subthing_twos_id').to be_true
        end
      end
    
      after :all do
        rollback_all
      end
    end
  end
end