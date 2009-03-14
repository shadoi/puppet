require 'puppet/indirector/terminus'

class Puppet::Indirector::DataMapper < Puppet::Indirector::Terminus
    desc "Retrieve and store catalog data via DataMapper"

    def find(request)
    end

    def save(node, resources)
        # not sure if we'll be doing this for DM going forward..
        unless Puppet.features.rails?
            raise Puppet::Error,
                "storeconfigs is enabled but rails is unavailable"
        end

        # need an equivalent check for connection?  maybe DataMapper::Transaction
        #unless ActiveRecord::Base.connected?
            #Puppet::Rails.connect
        #end

        begin
            # We store all of the objects, even the collectable ones
            benchmark(:info, "Stored catalog for #{node.name}") do
                Puppet::DataMapper::Host.transaction do
                    Puppet::DataMapper::Host.store(node, resources)
                end
            end
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.err "Could not store configs: %s" % detail.to_s
        end
    end

    private

    def from_dm(text)
    end

    def to_dm(object)
    end
end
