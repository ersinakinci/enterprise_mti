module EnterpriseMti
  module ClassMethods
    def has_subclass(subclass_symbol, options={})
    
      subclass_name           = subclass_symbol.to_s.camelize
      subclass                = nil
      subclass_qualified_name = (options[:module] || '') + '::' + subclass_name
      superclass              = self
      superclass_name         = self.name.demodulize.underscore
      superclass_symbol       = self.name.demodulize.underscore.to_sym
      table_name              = options[:table_name] || subclass_symbol.to_s.pluralize
    
      # Get subclass
      Kernel.const_get(options[:module] || 'Kernel').module_eval {
        subclass = const_get subclass_name }
    
      subclass.class_eval do
        # Set table name on subclass to prevent it from inheriting
        # superclass' attributes, etc.
        self.table_name = table_name
        has_one superclass_symbol
        attr_accessor :superclass_instance
        validates :superclass_instance, presence: true
      
        define_method "#{superclass_name}_transaction" do
          superclass_instance.send "#{subclass_symbol.to_s}_id=", self.id
          superclass_instance.save
        end
        after_save "#{superclass_name}_transaction".to_sym, on: :create
      end
    
      # Superclass belongs to subclass
      self.belongs_to subclass_symbol, :class_name => subclass_qualified_name
    end
  
    def is_a_superclass

      # Require subclasses' files as dependencies, otherwise we get circular
      # dependency errors (see https://github.com/rails/rails/issues/3364)
      if descendants.empty?
        module_path_tokens = self.name.underscore.split('/')
        module_path_tokens[-1] += '_subclasses'
        Dir[Rails.root.join('app', 'models', File.join(module_path_tokens), "*.rb")].each do |file|
          require_dependency file
        end
      end
    
      # Call has_sublcass on the superclass for each subclass
      descendants.each do |subclass|
        name_tokens = subclass.to_s.split('::')
        subclass_name = name_tokens.last
        module_name = name_tokens[0...-1].join('::') if name_tokens.count > 1
        self.send :has_subclass, subclass_name.underscore.to_sym, :module => module_name
      end
    
      # Populate container_classes, an array that contains classes that "have"
      # the superclass (and thus have foreign key constraints on the
      # superclass)
      reflection_class = Proc.new do |r|
        if r.options[:class_name]
          r.options[:class_name].constantize
        else
          prefix = self.name.deconstantize || ''
          "#{prefix}::#{r.name.to_s.camelize}".constantize
        end
      end
      
      @container_classes = self.reflect_on_all_associations.keep_if { |r|
        r.macro == :belongs_to &&
        #self.column_names.include?(r.association_foreign_key) &&
        !self.descendants.include?(reflection_class.call(r))
      }.collect { |r| reflection_class.call(r) }
    
      # Add read-only access to container_classes
      class << self
        def container_classes
          @container_classes
        end
      end
    end
  
    def has_one_superclass(superclass_symbol, options={})
    
      superclass_name                 = superclass_symbol.to_s.camelize
      superclass_qualified_name       = (options[:module] || '') + '::' + superclass_name
      superclass                      = superclass_qualified_name.constantize
      container_class                 = self
      container_class_camel_name      = self.name.demodulize
      container_class_underscore_name = self.name.demodulize.underscore
      superclass_relation_name        = superclass_symbol.to_s + "_superclass"
      superclass_relation_symbol      = superclass_relation_name.to_sym
    
      has_one superclass_relation_symbol, class_name: superclass_qualified_name
    
      # Create build and create methods for each subclass
      superclass.descendants.each do |subclass|
        subclass_underscore_name = subclass.name.demodulize.underscore
        actions = [:build, :create, :create!]
      
        actions.each do |action|
          action_suffix = nil
          action_name   = action.to_s
        
          if action.to_s.last(1) == '!'
            action_suffix = '!'
            action_name   = action.to_s[0..-2]
          end

          subclass.define_singleton_method "#{action_name}_with_superclass_instance#{action_suffix}" do |*args, &block|
            self.send("#{action_name}#{action_suffix}", *args, &block).superclass_instance = args.last[:superclass_instance]
          end
        
          superclass.class_eval do
          
            define_method "#{action_name}_#{subclass_underscore_name}_subclass#{action_suffix}" do |*args, &block|
              args.last[:superclass_instance] = self
              subclass.send "#{action_name}_with_superclass_instance#{action_suffix}", *args, &block
            end
          
            define_method "#{subclass_underscore_name}_with_superclass_instance=" do |value|
              value.superclass_instance = self
              self.send "#{subclass_underscore_name}=", value
            end
          end

          container_class.class_eval do
          
            define_method "#{action_name}_#{subclass_underscore_name}#{action_suffix}" do |*args, &block|
              unless superclass_instance = self.send(superclass_relation_symbol)
                superclass_instance = self.send("build_#{superclass_relation_name}")
              end
              superclass_instance.instance_eval do
                send "#{action_name}_#{subclass_underscore_name}_subclass#{action_suffix}", *args, &block
              end
            end
          end
        end
      end
    
      # Create getter
      define_method superclass_symbol do

        association_methods = superclass.descendants.collect { |subclass|
          reflection_symbol =
            subclass.to_s.demodulize.underscore.to_sym
          assoc = superclass.reflect_on_association(reflection_symbol)
          assoc ? assoc.name : nil
        }.compact
      
        if superclass_model_instance = self.send(superclass_relation_symbol)
          association_methods.collect{ |a|
            superclass_model_instance.send a
          }.inject do |a, b|
            a || b
          end
        end
      end
    
      # Create setter
      define_method "#{superclass_symbol.to_s}=" do |value|
        reflection_symbol =
          value.class.name.demodulize.underscore.to_sym

        unless superclass_instance = self.send(superclass_relation_symbol)
          superclass_instance = self.send("build_#{superclass_relation_name}")
        end
      
        reflection_assignment_method =
          superclass.reflect_on_association(reflection_symbol).name.to_s + '_with_superclass_instance='
        
        superclass_instance.send reflection_assignment_method, value
      end
    end
  end
end