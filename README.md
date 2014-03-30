Enterprise MTI
==============

Add multiple table inheritance with database-backed referential integrity to your Active Record models.

About
-----

Enterprise MTI is a Ruby library for adding multiple table inheritance to your Active Record models.  Unlike other MTI libraries, its design enforces referential integrity at both the application and database levels.  The library's name, its architectural principles, and some of its code are derived from [Dan Chak's](http://dan.chak.org) excellent book, [*Enterprise Rails*](http://www.amazon.com/Enterprise-Rails-Dan-Chak/dp/0596515200).

Current status
--------------

Enterprise MTI only supports PostgreSQL at the moment but is designed in a way to allow for other RDBMS's to be supported in the future.  MySQL isn't supported because it doesn't offer deferred constraint checking.

The library also only supports one-to-one associations at the moment, but one-to-many and many-to-many support is actively being worked on.

How does it work?
-----------------

Enterprise MTI deals with three types of models and their corresponding tables:

* **Superclass**: The parent (ancestor) model and its table
* **Subclasses**: The child (inheriting) models and their tables
* **Container class**: The model that appears to have direct access to the subclass models

For example, given a container class `Closet`, a superclass `Shoes`, and subclasses `RedShoes` and `WhiteShoes`, you can do this:

    closet = Closet.new
    closet.shoes = RedShoes.new || WhiteShoes.new
    closet.red_shoes = RedShoes.new
    closet.white_shoes = WhiteShoes.new
    closet.build_white_shoes
    closet.create_red_shoes

Any methods accessible to subclass instances are also magically accessible to superclass instances:

    closet.shoes.ruby?           # => returns "true" if we have red shoes
    closet.shoes.white_intensity # => returns white_shoes(white_intensity)

Installation
------------

Using RubyGems:

    gem install enterprise_mti
    
Or, place it in your Gemfile along with a supported database...

    gem 'enterprise_mti'
    gem 'pg'       # supported
    #gem 'sqlite'    unsupported
    #gem 'mysql'     unsupported
    
...and install with Bundler:

    bundle install

Setup (summary)
---------------

1. Create superclass model and migration
2. Create subclass models and migrations
3. Create container class model and migration
4. Create Enterprise MTI migration
5. Migrate DB
6. Start enjoying the awesomeness

Setup (details)
---------------

**1. Create superclass model and migration**

Create your superclass model and migration as you would any other model and migration: `rails g model Shoe`, etc.

Add `has_mti_subclass` to the model.  No modification to the migration is necessary.

    class Shoe < ActiveRecord::Base
      has_mti_subclass :red_shoe
      has_mti_subclass :white_shoe
    end

If your subclasses are contained within a module, use the `class_name:` option:

    class Shoe < ActiveRecord::Base
      has_mti_subclass :red_shoe, class_name: 'Physical::Clothing::RedShoe'
      has_mti_subclass :white_shoe, class_name: 'Physical::Clothing::WhiteShoe'
    end

**2. Create subclass models and migrations**

Create your subclass models and migrations as you would any other models and migrations: `rails g model RedShoe`, `rails g model WhiteShoe`, etc.

Add `belongs_to_mti_superclass` to the model.  No modification to the migration is necessary.

    class RedShoe < ActiveRecord::Base
      belongs_to_mti_superclass :shoe
    end
    
    class WhiteShoe < ActiveRecord::Base
      belongs_to_mti_superclass :shoe
    end

If your superclass is contained within a module, use the `class_name:` option:

    class RedShoe < ActiveRecord::Base
      belongs_to_mti_superclass :shoe, class_name: 'Physical::Clothing::Shoe'
    end
    
    class WhiteShoe < ActiveRecord::Base
      belongs_to_mti_superclass :shoe, class_name: 'Physical::Clothing::Shoe'
    end

**3. (Optional: create container class model and migration)**

Add a relationship between the container and the superclass.  No modification to the migration is necessary.

    class Closet < ActiveRecord::Base
      has_one_mti_superclass :shoe
    end
    
    class Shoe < ActiveRecord::Base
      has_mti_subclass :red_shoe
      has_mti_subclass :white_shoe
      belongs_to_mti_container_class :closet
    end

Currently, only `has_one_mti_superclass` (i.e., `has_one`) is defined.  Using `has_one_mti_superclass` effectively means that the container model is in a one-to-one relationship with your subclass models.

If your superclass is contained within a module, use the `module:` option:

    class Closet < ActiveRecord::Base
      has_one_superclass :shoe, class_name: 'Physical::Clothing::Shoe'
    end
    
    class Shoe < ActiveRecord::Base
      has_mti_subclass :red_shoe, class_name: 'Physical::Clothing::RedShoe'
      has_mti_subclass :white_shoe, class_name: 'Physical::Clothing::WhiteShoe'
      belongs_to_mti_container_class :closet, class_name: 'Physical::Clothing::Closet'
    end

**4. Create Enterprise MTI migration**

Create a migration that runs `enterprise_mti_up` and `enterprise_mti_down` when migrating and rolling back, respectively.

    class StartEnterpriseMti < ActiveRecord::Migration
      SUBCLASS_TABLES = ['red_shoes', 'white_shoes']
    
      def up
        enterprise_mti_up superclass_table: 'shoes', subclass_tables: SUBCLASS_TABLES
      end
  
      def down
        enterprise_mti_down superclass_table: 'shoes', subclass_tables: SUBCLASS_TABLES
      end
    end

**5. Migrate DB**
 
    rake db:migrate

**6. Start enjoying the awesomeness**
 
    closet = Closet.new
    closet.shoes = RedShoes.new || WhiteShoes.new
    closet.red_shoes = RedShoes.new
    closet.white_shoes = WhiteShoes.new
    closet.build_white_shoes
    closet.create_red_shoes
    
Contribute
==========

Please!  The following are especially needed at the moment:

* More spec tests
* Support for more databases
* Support for one-to-many and many-to-many associations

Issue a pull request and start hacking!

Credits
=======

Enterprise MTI is developed and maintained by [Ersin Akinci](http://www.ersinakinci.com).  Drop him a line on [Twitter](https://twitter.com/earksiinni).

The original inspiration, design, and code for Enterprise MTI was provided by [Dan Chak](http://dan.chak.org) and his excellent book, [*Enterprise Rails*](http://www.amazon.com/Enterprise-Rails-Dan-Chak/dp/0596515200).  A highly recommended read for all Rails enthusiasts.

License
=======

MIT License.  Copyright 2013-2014 [Ersin Akinci](http://www.ersinakinci.com).
