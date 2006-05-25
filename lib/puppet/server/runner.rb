module Puppet
class Server
    class MissingMasterError < RuntimeError # Cannot find the master client
    end
    # A simple server for triggering a new run on a Puppet client.
    class Runner < Handler
        @interface = XMLRPC::Service::Interface.new("puppetrunner") { |iface|
            iface.add_method("string run(string, string)")
        }

        # Run the client configuration right now, optionally specifying
        # tags and whether to ignore schedules
        def run(tags = [], ignoreschedules = false, bg = true, client = nil, clientip = nil)
            # We need to retrieve the client
            master = Puppet::Client::MasterClient.instance

            unless master
                raise MissingMasterError, "Could not find the master client"
            end

            if master.locked?
                Puppet.notice "Could not trigger run; already running"
                return "running"
            end

            if tags == ""
                tags = nil
            end

            if ignoreschedules == ""
                ignoreschedules == nil
            end

            if client
                msg = "%s(%s) triggered run" % [client, clientip]
                if tags
                    msg += " with tags %s" % tags.join(", ")
                end

                if ignoreschedules
                    msg += " without schedules"
                end

                Puppet.notice msg
            end

            # And then we need to tell it to run, with this extra info.
            # By default, stick it in a thread
            if bg
                Puppet.newthread do
                    master.run(tags, ignoreschedules)
                end
            else
                master.run(tags, ignoreschedules)
            end

            return "success"
        end
    end
end
end

# $Id$