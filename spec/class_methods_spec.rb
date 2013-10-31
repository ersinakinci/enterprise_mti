require 'spec_helper'
require 'helpers/migration_spec_helpers'
require 'helpers/class_methods_spec_helpers'

describe EnterpriseMti::ClassMethods do
  include MigrationHelpers
  include ClassMethodsHelpers
  
  context 'having migrated superclass, subclasses, and MTI,' do
    
    before :all do
      migrate_all
    end
    
    let(:container_instance) { Container.new }
    
    context 'the superclass' do
      
      it 'belongs_to the first subclass' do
        expect(Superthing.reflect_on_association(:subthing_one).macro == :belongs_to).to be_true
      end
      
      it 'belongs_to the second subclass' do
        expect(Superthing.reflect_on_association(:subthing_two).macro == :belongs_to).to be_true
      end
    end
    
    context 'the container class' do
      
      it 'has_one of the superclass' do
        expect(Container.reflect_on_association(:superthing_superclass).macro == :has_one).to be_true
      end
    end
    
    context 'a container instance' do
      
      it 'responds_to a getter method named after the superclass' do
        expect(container_instance.respond_to? :superthing).to be_true
      end
      
      it 'responds_to a setter method named after the superclass' do
        expect(container_instance.respond_to? :superthing=).to be_true
      end
      
      it 'responds_to a build helper named after the first subclass' do
        expect(container_instance.respond_to? :build_subthing_one).to be_true
      end
      
      it 'responds_to a build helper named after the second subclass' do
        expect(container_instance.respond_to? :build_subthing_two).to be_true
      end
    end
    
    context 'the first subclass' do
      
      it 'has_one of the superclass' do
        expect(SubthingOne.reflect_on_association(:superthing).macro == :has_one).to be_true
      end
    end
    
    context 'the second subclass' do
      
      it 'has_one of the superclass' do
        expect(SubthingTwo.reflect_on_association(:superthing).macro == :has_one).to be_true
      end
    end
    
    after :all do
      rollback_all
    end
  end
end