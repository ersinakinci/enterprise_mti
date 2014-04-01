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
    
    private
    
      def create_create_methods(caller, target_camel_names, *args)
        opts = (args.last.class == Hash ? args.last : {})
        actions = [:create, :create!]
        caller_name = caller.name.demodulize.underscore
        
        target_camel_names.each do |target_camel_name|
          target_name = target_camel_name.demodulize.underscore
          actions.each do |action|
            suffix = "!" if action[-1] == "!"
            action = action[0..-2] if suffix
            caller_method, caller_instance_method, target_method, eigenclass = nil
            
            if opts[:for_superclass] == true
              caller_method = "#{action}_#{target_name}#{suffix}"
              caller_create_instance_method = "#{action}#{suffix}"
              target_method = "#{action}_without_enterprise_mti#{suffix}"
            else
              caller_method = "#{action}_with_enterprise_mti#{suffix}"
              caller_create_instance_method = "#{action}_without_enterprise_mti#{suffix}"
              target_method = "#{action}#{suffix}"
              eigenclass = class << caller; self; end
            end
            
            # E.g., Car.create_red_car!() =>
            #       red_car = RedCar.create!() && red_car.superclass_instance = Car.create!()
            caller.define_singleton_method caller_method do |*args, &block|
              target = target_camel_name.constantize
              caller_instance = nil
              ActiveRecord::Base.transaction do
                args << {} unless args.last.class == Hash
                
                caller_args = Array.new(args)
                caller_args[-1] = caller_args.last.select { |k,v| EnterpriseMti::ClassMethods::column_methods_and_types(caller).include? k.to_s }
                target_args = Array.new(args)
                target_args[-1] = target_args.last.select { |k,v| EnterpriseMti::ClassMethods::column_methods_and_types(target).include? k.to_s }
                
                if opts[:for_superclass] == true
                  # Caller is superclass, target is subclass
                  caller_instance = caller.send caller_create_instance_method, *caller_args
                  target_args[-1][caller_name] = caller_instance
                  target_instance = target.send target_method, *target_args
                  caller_instance.send("#{target_name}=", target_instance)
                  caller_instance.save
                else
                  # Caller is subclass, target is superclass
                  binding.pry
                  target_instance = target.send target_method, *target_args
                  caller_args[-1][target_name] = target_instance
                  caller_instance = caller.send caller_create_instance_method, *caller_args
                  target_instance.send("#{caller_name}=", caller_instance)
                  target_instance.save
                end
              end
              caller_instance
            end
            eigenclass.alias_method_chain("#{action}#{suffix}".to_sym, :enterprise_mti) unless opts[:for_superclass]
          end
        end
      end
    
    public
    
    def self.column_methods_and_types(klass)
      methods = klass.reflect_on_all_associations.collect { |r| r.name.to_s } +
                klass.reflect_on_all_associations.collect { |r| "#{r.name.to_s}=" } +
                klass.reflect_on_all_associations.collect { |r| "#{r.name.to_s}?" } +
                klass.column_methods_hash.keys.collect { |key| key.to_s}
      return methods
    end
    
    def belongs_to_mti_superclass(*args, &block)
      opts = (args.last.class == Hash ? args.last : {})
      superc_camel_name = (opts[:class_name] || args.first).to_s.camelize
      belongs_to args.first, class_name: superc_camel_name # E.g., RedCar.has_one :car
      
      # SUBCLASS INSTANCE METHODS
      define_method :mti_superclass do
        superc_camel_name.constantize
      end
      
      # SUBCLASS CLASS METHODS
      instance_exec self, [superc_camel_name], &method(:create_create_methods)
    end
    
    def has_mti_subclass(*args, &block)
      
      # Require subclasses' files as dependencies, otherwise we get circular
      # dependency errors (see https://github.com/rails/rails/issues/3364)
      #if descendants.empty?
      #  module_path_tokens = self.name.underscore.split('/')
      #  module_path_tokens[-1] += '_subclasses'
      #  Dir[Rails.root.join('app', 'models', File.join(module_path_tokens), "*.rb")].each do |file|
      #    require_dependency file
      #  end
      #end
      
      opts = (args.last.class == Hash ? args.last : {})
      subc_camel_name = (opts[:class_name] || args.first).to_s.camelize
      superc_name = self.name.demodulize.underscore
      @subc_camel_names ||= []
      @subc_camel_names << subc_camel_name
      
      belongs_to args.first, class_name: subc_camel_name
      
      # SUPERCLASS CLASS METHODS
      class << self
        # Read-only access to subclasses
        def mti_subclasses
          @subc_camel_names.collect { |subc_camel_name| subc_camel_name.constantize }
        end
        
        def mti_subclass_names
          @subc_camel_names
        end
      end
      instance_exec self, @subc_camel_names, for_superclass: true, &method(:create_create_methods)
      
      # SUPERCLASS INSTANCE METHODS
      
      define_method :mti_subclass_instance do
        self.class.mti_subclasses.each do |subc|
          subc_name = subc.name.demodulize.underscore
          if self.respond_to?(subc_name) && self.send(subc_name)
            return self.send(subc_name)
          end
        end
        nil
      end
      
      define_method :mti_attributes_hash do
        sub_attrs = []
        sub_attrs = self.mti_subclass_instance.class.columns_hash.values if self.mti_subclass_instance
        
        attrs = (self.class.columns_hash.values + sub_attrs).index_by { |rec| rec.name }.values
        attrs.inject({}) { |ret, element| ret[element.name] = element.type; ret }
      end
      
      define_method :mti_useful_attributes_hash do
        self.mti_attributes_hash.select {|k,v| k !~ /(^id|_id|created_at|updated_at)$/}
      end
      
      # Attempt to redirect subclass column methods
      # E.g., car.red_intensity and car.red_intensity= just work
#=begin
      # TODO: Refactor
      define_method :method_missing do |method, *args, &block|
        #binding.pry
        if (self.mti_subclass_instance)
          klass = self.mti_subclass_instance.class
          methods = EnterpriseMti::ClassMethods::column_methods_and_types(klass)
          return self.mti_subclass_instance.send(method, *args, &block) if methods.include?(method.to_s)
        else
          super(method, *args, &block)
        end
      end
      
      define_method :respond_to_missing? do |method, *args|
        #binding.pry
        
        if (self.mti_subclass_instance)
          klass = self.mti_subclass_instance.class
          methods = EnterpriseMti::ClassMethods::column_methods_and_types(klass)
          return true if methods.include?(method.to_s)
        else
          super(method, *args)
        end
      end
#=end
      
      # method_missing alternative, performance would be better, but since we
      # can't guarantee the load order of the classes, the constantize call
      # will generally fail.  TODO?
=begin
      (subc_camel_name.constantize.columns - self.columns).each do |target_column|
        [target_column, "#{target_column}="].each do |action|
          unless self.respond_to? action
            define_method action do |*args, &block|
              self.class.mti_subclass_names.each do |subc_camel_name|
                subc_name = subc_camel_name.demodulize.underscore
                if self.send(subc_name)
                  return self.send(subc_name).send(action, *args, &block)
                end
              end
            end
          end
        end
      end
=end
    end
    
    def has_one_mti_superclass(*args, &block)
      opts                            = (args.last.class == Hash ? args.last : {})
      superc_sym                      = args.first
      superc_camel_name               = (opts[:class_name] || args.first).to_s.camelize
      superc                          = superc_camel_name.constantize
      
      # Container class has one superclass | Garage.has_one :car
      has_one superc_sym, class_name: superc_camel_name
      
      # CONTAINER CLASS CLASS METHODS
      # Create build and create methods for each subclass
      superc.mti_subclass_names.each do |subc_camel_name|
        subc_name = subc_camel_name.demodulize.underscore
        
        actions = [:create, :create!]
        actions.each do |action|
          suffix = "!" if action[-1] == "!"
          action = action[0..-2] if suffix
          
          # E.g., garage.create_red_car!
          define_singleton_method "#{action}_#{subc_name}#{suffix}" do |*args, &block|
            
            ActiveRecord::Base.transaction do
              superc_instance = superc.send("#{action}_#{subc_name}#{suffix}", *args, &block)
              self.send("#{superc_sym}=", superc_instance)
              self.save
            end
          end
        end
      end
    end
    
    def belongs_to_mti_container_class(*args, &block)
      belongs_to *args, &block
    end
  end
end