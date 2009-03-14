require 'puppet/indirector/terminus'

class Puppet::Indirector::ActiveRecord < Puppet::Indirector::Terminus
    desc "Retrieve and store catalog data via ActiveRecord"

    def find(request)
    end

    def save(node, resources)
        # Store the catalog into the database, using the old rails code for now.
        unless Puppet.features.rails?
            raise Puppet::Error,
                "storeconfigs is enabled but rails is unavailable"
        end

        unless ActiveRecord::Base.connected?
            Puppet::Rails.connect
        end

        # We used to have hooks here for forking and saving, but I don't
        # think it's worth retaining at this point.
        begin
            # We store all of the objects, even the collectable ones
            benchmark(:info, "Stored catalog for #{node.name}") do
                Puppet::Rails::Host.transaction do
                    Puppet::Rails::Host.store(node, resources)
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

    def from_ar(text)
    end

    def to_ar(object)
    end
end
