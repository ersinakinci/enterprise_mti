module EnterpriseMti
  module ClassMethods
    
    # NOTE
    # The comments below use the following examples:
    #   Garage                          (container class, inherits from ActiveRecord::Base)
    #   Car                             (superclass, inherits from ActiveRecord::Base)
    #   RedCar                          (subclass, inherits from Car)
    #   WhiteCar                        (subclass, inherits from Car)
    #   garage, car, red_car, white_car (instances of the above classes)
    #   red_intensity, white_intensity  (attributes of above subclasses)
    def has_subclass(subc_sym, options={})
    
      subc_camel_name   = subc_sym.to_s.camelize
      subc              = nil
      subc_name         = nil
      superc            = self
      superc_name       = self.name.demodulize.underscore
      table_name        = options[:table_name] || subc_sym.to_s.pluralize
      module_name       = options[:class_name] ? options[:class_name].to_s.split("::")[0..-2].join("::") : nil
    
      # Get subclass (e.g., RedCar)
      Kernel.const_get(module_name || 'Kernel').module_eval { subc = const_get subc_camel_name }
      subc_name = subc.name.demodulize.underscore
        
      # Superclass belongs to subclass | Car.belongs_to :red_car
      if options[:class_name]
        self.belongs_to subc_sym, class_name: options[:class_name]
      else
        self.belongs_to subc_sym
      end
      
      # SUBCLASS INSTANCE METHODS
      subc.class_eval do
        self.table_name = table_name  # Set table name on subclass to prevent it from inheriting superclass' attributes, etc.
        belongs_to superc_name.to_sym # E.g., RedCar.has_one :car
        
        define_method :superclass do
          superc
        end
      end
      
      # SUBCLASS CLASS METHODS
      actions = [:create, :create!]
      actions.each do |action|
        suffix = "!" if action[-1] == "!"
        action = action[0..-2] if suffix

        subc.define_singleton_method("#{action}_with_auto_superclass#{suffix}") do |*args|
          subc_instance = nil
          ActiveRecord::Base.transaction do
            args << {} unless args.last.class == Hash
            superc_args = Array.new(args)
            superc_args[-1] = superc_args.last.select { |k,v| superc.attribute_names.include? k.to_s }
            subc_args = Array.new(args)
            subc_args[-1] = subc_args.last.select { |k,v| subc.attribute_names.include? k.to_s }
            
            superc_instance = superc.send action, *superc_args
            subc_args[-1][superc_name] = superc_instance
            subc_instance = subc.send "#{action}_without_auto_superclass#{suffix}", *subc_args
            superc_instance.send("#{subc_name}_id=", subc_instance.id)
            superc_instance.save
          end
          subc_instance
        end
        eigenclass = class << subc; self; end
        eigenclass.alias_method_chain "#{action}#{suffix}".to_sym, :auto_superclass
      end
    end
  
    def is_a_superclass
      superc_name = self.name.demodulize.underscore
      superc = self

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
      # E.g., Car.descendants.each { |subclass| Car.has_subclass subclass }
      descendants.each do |subclass|
        subc_short_name = subclass.to_s.split('::').last.underscore
        #module_name = name_tokens[0...-1].join('::') if name_tokens.count > 1
        self.send :has_subclass, subc_short_name.to_sym, class_name: subclass.name
      end
    
      # Populate container_classes, an array that contains classes that "have"
      # the superclass (and thus have foreign key constraints on the
      # superclass)
      # Step 1
      reflection_class = Proc.new do |r|
        if r.options[:class_name]
          r.options[:class_name].constantize
        else
          prefix = self.name.deconstantize || ''
          "#{prefix}::#{r.name.to_s.camelize}".constantize
        end
      end
      
      # Step 2
      @container_classes = self.reflect_on_all_associations.keep_if { |r|
        r.macro == :belongs_to &&
        #self.column_names.include?(r.association_foreign_key) &&
        !self.descendants.include?(reflection_class.call(r))
      }.collect { |r| reflection_class.call(r) }
      
      # SUPERCLASS INSTANCE METHODS
      self.class_eval do        
        # Attempt to redirect unknown methods to subclass instances
        # E.g., car.red_intensity just works
        # TODO: errors may arise if superclass is the parent of more than one
        # set of classes.
        def method_missing_with_subclass_passthrough(method, *args)
          self.class.descendants.each do |subc|
            subc_name = subc.name.demodulize.underscore
            if self.respond_to?(subc_name) && self.send(subc_name) && self.send(subc_name).respond_to?(method)
              return self.send(subc_name).send(method, *args)
            else
              method_missing_without_subclass_passthrough(method, *args)
            end
          end
        end
        
        alias_method_chain :method_missing, :subclass_passthrough
      end
=begin
      self.class_eval do
        # E.g., car.red_car => car.red
        #       car.red_car = red_car => car.red = red_car
        #self.descendants.collect { |subclass| subclass.name.demodulize.underscore.split("_")[0..-2].join("_") }.each do |accessor|
        #  define_method accessor do |*args, &block|
        #    self.send("#{accessor}_#{superc_name}", *args, &block)
        #  end
          
        #  define_method "#{accessor}=" do |*args, &block|
        #    self.send("#{accessor}_#{superc_name}=", *args, &block)
        #  end
        #end
        
        self.descendants.each do |subc|
          subc_name = subc.name.demodulize.underscore  
          define_method "#{subc_name}=" do |value|
            #if self.new_record?
            #  raise SuperclassNotSavedError, "Cannot assign a subclass instance to a superclass that is not yet saved, please save the superclass first"
            #end
            if (value.send(superc_name) != self) && (value.send(superc_name) != nil)
              raise SuperclassInstanceError, "Trying to assign a subclass instance to a superclass, but the subclass already has a superclass"
            end
            value.send("#{superc_name}=", self)
            self.instance_variable_set("@#{subc_name}", value)
          end
        end
      end
=end
            
      # SUPERCLASS CLASS METHODS
      class << self
        # Add read-only access to container_classes
        def container_classes
          @container_classes
        end
      end
      
      # TODO: Refactor code below
      actions = [:create, :create!]
      self.descendants.each do |subc|
        subc_name = subc.name.demodulize.underscore
        actions.each do |action|
          suffix = "!" if action[-1] == "!"
          action = action[0..-2] if suffix
          
          # E.g., Car.create_red_car!() =>
          #       red_car = RedCar.create!() && red_car.superclass_instance = Car.create!()
          superc.define_singleton_method "#{action}_#{subc_name}#{suffix}" do |*args, &block|
            superc_instance = nil
            ActiveRecord::Base.transaction do
              #puts "ARGS: " + args.to_s
              args << Hash.new unless args.last.class == Hash
              #puts "ARGS: " + args.to_s
              superc_args = Array.new(args)
              #puts "SUPERC ARGS: " + superc_args.to_s
              superc_args[-1] = superc_args.last.select { |k,v| superc.attribute_names.include? k.to_s }
              #puts "SUPERC ARGS: " + superc_args.to_s
              subc_args = Array.new(args)
              #puts "SUBC ARGS: " + subc_args.to_s
              subc_args[-1] = subc_args.last.select { |k,v| subc.attribute_names.include? k.to_s }
              #puts "SUBC ARGS: " + subc_args.to_s
              #puts "SUPERC ARGS: " + superc_args.to_s
              #puts "SUBC: #{subc.inspect}"
              #puts "SUPERC: #{superc.inspect}"
          
              superc_instance = superc.send action, *superc_args
              #puts "SUBC ARGS: " + subc_args.to_s
              subc_args[-1][superc_name] = superc_instance
              #puts "SUBC ARGS: " + subc_args.to_s
              subc_instance = subc.send "#{action}_without_auto_superclass#{suffix}", *subc_args
              superc_instance.send("#{subc_name}_id=", subc_instance.id)
              superc_instance.save
            end
            superc_instance
          end
        end
      end
    end
  
    def has_one_superclass(superc_sym, options={})
    
      superc                          = options[:class_name] ? options[:class_name].constantize : superc_sym.constantize
      superc_camel_name               = superc_sym.to_s.camelize
      container_class                 = self
      container_class_camel_name      = self.name.demodulize
      container_class_underscore_name = self.name.demodulize.underscore
      #superclass_relation_name        = superclass_symbol.to_s + "_superclass"
      #superclass_relation_symbol      = superclass_relation_name.to_sym
      
      # Container class has one superclass | Garage.has_one :car
      if options[:class_name]
        self.has_one superc_sym, class_name: options[:class_name]
      else
        self.has_one superc_sym
      end
    
      # Create build and create methods for each subclass
      superc.descendants.each do |subc|
        subc_name = subc.name.demodulize.underscore
        actions = [:create, :create!]
      
        actions.each do |action|
          suffix = "!" if action[-1] == "!"
          action = action[0..-2] if suffix
          
          container_class.class_eval do
            # E.g., garage.create_red_car!
            define_method "#{action}_#{subc_name}#{suffix}" do |*args, &block|
              ActiveRecord::Base.transaction do
                superc_instance = superc.send("#{action}_#{subc_name}", *args, &block)
                self.send("#{superc_sym}=", superc_instance)
                self.save
              end
            end
          end
        end
      end
=begin
      # Create getter
      define_method superc_sym do

        association_methods = superc.descendants.collect { |subclass|
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
          superclass_instance = self.send("build_#{superclass_relation_name}") # Will be saved in after_save callback for subclass, see has_subclass
        end
        
        value.superclass_instance = superclass_instance
      
        reflection_assignment_method =
          superclass.reflect_on_association(reflection_symbol).name.to_s + '='
        
        superclass_instance.send reflection_assignment_method, value
      end
=end
    end
  end
end