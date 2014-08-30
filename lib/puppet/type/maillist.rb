module Puppet
    newtype(:maillist) do
        @doc = "Manage email lists.  This resource type currently can only create
            and remove lists, it cannot reconfigure them."

        ensurable do
            defaultvalues

            newvalue(:purged) do
                provider.purge
            end
        end

        newparam(:name, :namevar => true) do
            desc "The name of the email list."
        end

        newparam(:description) do
            desc "The description of the mailing list."
        end

        newparam(:password) do
            desc "The admin password."
        end

        newparam(:webserver) do
            desc "The name of the host providing web archives and the administrative interface."
        end

        newparam(:mailserver) do
            desc "The name of the host handling email for the list."
        end

        newparam(:admin) do
            desc "The email address of the administrator."
        end

        def generate
            if provider.respond_to?(:aliases)
                should = self.should(:ensure) || :present
                if should == :purged
                    should = :absent
                end
                atype = Puppet::Type.type(:mailalias)
                return provider.aliases.collect do |name, recipient|
                    if atype[name]
                        nil
                    else
                        malias = Puppet::Type.type(:mailalias).create(:name => name, :recipient => recipient, :ensure => should)
                    end
                end.compact
            end
        end
    end
end

