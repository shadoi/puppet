module Puppet
    Puppet.type(:file).ensurable do
        require 'etc'
        desc "Whether to create files that don't currently exist.
            Possible values are *absent*, *present* (will match any form of
            file existence, and if the file is missing will create an empty
            file), *file*, and *directory*.  Specifying ``absent`` will delete
            the file, although currently this will not recursively delete
            directories.

            Anything other than those values will be considered to be a symlink.
            For instance, the following text creates a link::

                # Useful on solaris
                file { \"/etc/inetd.conf\":
                    ensure => \"/etc/inet/inetd.conf\"
                }

            You can make relative links::

                # Useful on solaris
                file { \"/etc/inetd.conf\":
                    ensure => \"inet/inetd.conf\"
                }

            If you need to make a relative link to a file named the same
            as one of the valid values, you must prefix it with ``./`` or
            something similar.

            You can also make recursive symlinks, which will create a
            directory structure that maps to the target directory,
            with directories corresponding to each directory
            and links corresponding to each file."

        # Most 'ensure' properties have a default, but with files we, um, don't.
        nodefault

        newvalue(:absent) do
            File.unlink(@resource[:path])
        end

        aliasvalue(:false, :absent)

        newvalue(:file) do
            # Make sure we're not managing the content some other way
            if property = (@resource.property(:content) || @resource.property(:source))
                property.sync
            else
                @resource.write("", :ensure)
                mode = @resource.should(:mode)
            end
            return :file_created
        end

        #aliasvalue(:present, :file)
        newvalue(:present) do
            # Make a file if they want something, but this will match almost
            # anything.
            set_file
        end

        newvalue(:directory) do
            mode = @resource.should(:mode)
            parent = File.dirname(@resource[:path])
            unless FileTest.exists? parent
                raise Puppet::Error,
                    "Cannot create %s; parent directory %s does not exist" %
                        [@resource[:path], parent]
            end
            if mode
                Puppet::Util.withumask(000) do
                    Dir.mkdir(@resource[:path],mode)
                end
            else
                Dir.mkdir(@resource[:path])
            end
            @resource.send(:property_fix)
            @resource.setchecksum
            return :directory_created
        end


        newvalue(:link) do
            if property = @resource.property(:target)
                property.retrieve

                return property.mklink
            else
                self.fail "Cannot create a symlink without a target"
            end
        end

        # Symlinks.
        newvalue(/./) do
            # This code never gets executed.  We need the regex to support
            # specifying it, but the work is done in the 'symlink' code block.
        end

        munge do |value|
            value = super(value)

            # It doesn't make sense to try to manage links unless, well,
            # we're managing links.
            resource[:links] = :manage if value == :link
            return value if value.is_a? Symbol

            @resource[:target] = value
            resource[:links] = :manage

            return :link
        end

        def change_to_s(currentvalue, newvalue)
            if property = (@resource.property(:content) || @resource.property(:source)) and ! property.insync?(currentvalue)
                currentvalue = property.retrieve

                return property.change_to_s(property.retrieve, property.should)
            else
                super(currentvalue, newvalue)
            end
        end

        # Check that we can actually create anything
        def check
            basedir = File.dirname(@resource[:path])

            if ! FileTest.exists?(basedir)
                raise Puppet::Error,
                    "Can not create %s; parent directory does not exist" %
                    @resource.title
            elsif ! FileTest.directory?(basedir)
                raise Puppet::Error,
                    "Can not create %s; %s is not a directory" %
                    [@resource.title, dirname]
            end
        end

        # We have to treat :present specially, because it works with any
        # type of file.
        def insync?(currentvalue)
            if property = @resource.property(:source) and ! property.described?
                warning "No specified sources exist"
                return true
            end

            if self.should == :present
                if currentvalue.nil? or currentvalue == :absent
                    return false
                else
                    return true
                end
            else
                return super(currentvalue)
            end
        end

        def retrieve
            if stat = @resource.stat(false)
                return stat.ftype.intern
            else
                if self.should == :false
                    return :false
                else
                    return :absent
                end
            end
        end

        def sync
            @resource.remove_existing(self.should)
            if self.should == :absent
                return :file_removed
            end

            event = super

            return event
        end
    end
end

