#  Created by Blake Barnett on 2009-03-15.
#  Copyright (c) 2009. All rights reserved.

# Setup DataMapper connection details
module Puppet::DataMapper
    def self.connect

        # There doesn't appear to be an equivalent to ActiveRecord::Base.connected?
        # so we check if there storage exists for the current repository.
        return if DataMapper::Repository::Migration.storage_exists?(:default)

        # The :datamapper and :rails section should be genericized.
        Puppet.settings.use(:main, :datamapper, :puppetmasterd)
        DataMapper.setup(:default, database_arguments)

    end

    # The arguments for initializing the database connection.
    def self.database_arguments
        adapter = Puppet[:dbadapter]

        args = {:adapter => adapter}

        # TODO: Add some more storage types (couchdb, etc.)
        case adapter
        when "sqlite3":
            args[:dbfile] = Puppet[:dblocation]
        when "mysql", "postgresql":
            args[:host]     = Puppet[:dbserver] unless Puppet[:dbserver].empty?
            args[:username] = Puppet[:dbuser] unless Puppet[:dbuser].empty?
            args[:password] = Puppet[:dbpassword] unless Puppet[:dbpassword].empty?
            args[:database] = Puppet[:dbname]

            socket          = Puppet[:dbsocket]
            args[:socket]   = socket unless socket.empty?
        else
            raise ArgumentError, "Invalid db adapter %s" % adapter
        end
        args
    end

    # Set up our database connection.
    def self.init
        unless Puppet.features.data_mapper?
            raise Puppet::DevError, "No data_mapper, cannot init Puppet::DataMapper"
        end

        connect()

        # Needs a check to see if a past migration worked... don't think this works.
        # Also, so the models contain the schema information we don't need a schema.rb
        # Probably can just have all models defined in one file for easy inclusion.
        unless DataMapper::Repository.storage_exists?("resources")
            # Maybe this file just has migrate statements for each model?
            require 'puppet/data_mapper/database/schema'
        end

        if Puppet[:dbmigrate]
            migrate()
        end
    end

    def self.migrate
        # Destructive migration!  
        DataMapper::Migration.auto_migrate!
    end
end    

if Puppet.features.data_mapper?
    require 'puppet/data_mapper/host'
end
