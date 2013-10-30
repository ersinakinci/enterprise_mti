require 'enterprise_mti/class_methods'
require 'enterprise_mti/migration'

module EnterpriseMti
  extend ActiveSupport::Concern
end

ActiveRecord::Base.send :include, ::EnterpriseMti
ActiveRecord::Migration.send :include, ::EnterpriseMti::Migration