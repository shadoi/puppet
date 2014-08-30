# Manage file group ownership.
module Puppet
    Puppet.type(:file).newproperty(:group) do
        require 'etc'
        desc "Which group should own the file.  Argument can be either group
            name or group ID."
        @event = :file_changed

        validate do |group|
            raise(Puppet::Error, "Invalid group name '%s'" % group.inspect) unless group and group != ""
        end

        def id2name(id)
            return id.to_s if id.is_a?(Symbol)
            return nil if id > Puppet[:maximum_uid].to_i
            begin
                group = Etc.getgrgid(id)
            rescue ArgumentError
                return nil
            end
            if group.gid == ""
                return nil
            else
                return group.name
            end
        end

        # We want to print names, not numbers
        def is_to_s(currentvalue)
            if currentvalue.is_a? Integer
                id2name(currentvalue) || currentvalue
            else
                return currentvalue.to_s
            end
        end

        def should_to_s(newvalue = @should)
            if newvalue.is_a? Integer
                id2name(newvalue) || newvalue
            else
                return newvalue.to_s
            end
        end

        def retrieve
            if self.should
                @should = @should.collect do |val|
                    unless val.is_a?(Integer)
                        if tmp = validgroup?(val)
                            val = tmp
                        else
                            raise "Could not find group %s" % val
                        end
                    else
                        val
                    end
                end
            end
            stat = @resource.stat(false)

            unless stat
                return :absent
            end

            # Set our method appropriately, depending on links.
            if stat.ftype == "link" and @resource[:links] != :follow
                @method = :lchown
            else
                @method = :chown
            end

            currentvalue = stat.gid

            # On OS X, files that are owned by -2 get returned as really
            # large GIDs instead of negative ones.  This isn't a Ruby bug,
            # it's an OS X bug, since it shows up in perl, too.
            if currentvalue > Puppet[:maximum_uid].to_i
                self.warning "Apparently using negative GID (%s) on a platform that does not consistently handle them" % currentvalue
                currentvalue = :silly
            end

            return currentvalue
        end

        # Determine if the group is valid, and if so, return the GID
        def validgroup?(value)
            if value =~ /^\d+$/
                value = value.to_i
            end

            if gid = Puppet::Util.gid(value)
                return gid
            else
                return false
            end
        end

        # Normal users will only be able to manage certain groups.  Right now,
        # we'll just let it fail, but we should probably set things up so
        # that users get warned if they try to change to an unacceptable group.
        def sync
            unless @resource.stat(false)
                stat = @resource.stat(true)
                currentvalue = self.retrieve

                unless stat
                    self.debug "File '%s' does not exist; cannot chgrp" %
                        @resource[:path]
                    return nil
                end
            end

            gid = nil
            unless gid = Puppet::Util.gid(self.should)
                raise Puppet::Error, "Could not find group %s" % self.should
            end

            begin
                # set owner to nil so it's ignored
                File.send(@method,nil,gid,@resource[:path])
            rescue => detail
                error = Puppet::Error.new( "failed to chgrp %s to %s: %s" %
                    [@resource[:path], self.should, detail.message])
                raise error
            end
            return :file_changed
        end
    end
end

