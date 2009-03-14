#  Created by Blake Barnett on 2009-03-15.
#  Copyright (c) 2009. All rights reserved.

require 'puppet/util/feature'

Puppet.features.add(:data_mapper) do
    unless defined? DataMapper
        begin
            require 'data_mapper'
        else 
            require 'rubygems'
            require 'data_mapper'
        rescue LoadError
            # Nothing
        end
    end

end

