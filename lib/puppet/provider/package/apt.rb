Puppet::Type.type(:package).provide :apt, :parent => :dpkg, :source => :dpkg do
    # Provide sorting functionality
    include Puppet::Util::Package

    desc "Package management via ``apt-get``."

    has_feature :versionable

    commands :aptget => "/usr/bin/apt-get"
    commands :aptcache => "/usr/bin/apt-cache"
    commands :preseed => "/usr/bin/debconf-set-selections"

    defaultfor :operatingsystem => :debian

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    # A derivative of DPKG; this is how most people actually manage
    # Debian boxes, and the only thing that differs is that it can
    # install packages from remote sites.

    def checkforcdrom
        unless defined? @@checkedforcdrom
            if FileTest.exists? "/etc/apt/sources.list"
                if File.read("/etc/apt/sources.list") =~ /^[^#]*cdrom:/
                    @@checkedforcdrom = true
                else
                    @@checkedforcdrom = false
                end
            else
                # This is basically a pathalogical case, but we'll just
                # ignore it
                @@checkedforcdrom = false
            end
        end

        if @@checkedforcdrom and @resource[:allowcdrom] != :true
            raise Puppet::Error,
                "/etc/apt/sources.list contains a cdrom source; not installing.  Use 'allowcdrom' to override this failure."
        end
    end

    # Install a package using 'apt-get'.  This function needs to support
    # installing a specific version.
    def install
        if @resource[:responsefile]
            self.run_preseed
        end
        should = @resource.should(:ensure)

        checkforcdrom()

        str = @resource[:name]
        case should
        when true, false, Symbol
            # pass
        else
            # Add the package version
            str += "=%s" % should
        end
        cmd = %w{-q -y}

        keep = ""
        if config = @resource[:configfiles]
            case config
            when :keep
                cmd << "-o" << 'DPkg::Options::=--force-confold'
            when :replace
                cmd << "-o" << 'DPkg::Options::=--force-confnew'
            else
                raise Puppet::Error, "Invalid 'configfiles' value %s" % config
            end
        end

        cmd << :install << str

        aptget(*cmd)
    end

    # What's the latest package version available?
    def latest
        output = aptcache :policy,  @resource[:name]

        if output =~ /Candidate:\s+(\S+)\s/
            return $1
        else
            self.err "Could not find latest version"
            return nil
        end
    end

	#
	# preseeds answers to dpkg-set-selection from the "responsefile"
	#
    def run_preseed
        if response = @resource[:responsefile] and FileTest.exists?(response)
            self.info("Preseeding %s to debconf-set-selections" % response)

            preseed response
        else
            self.info "No responsefile specified or non existant, not preseeding anything"
        end
    end

    def update
        self.install
    end

    def uninstall
        aptget "-y", "-q", :remove, @resource[:name]
    end

    def purge
        aptget '-y', '-q', 'remove', '--purge', @resource[:name]
        # workaround a "bug" in apt, that already removed packages are not purged
        super
    end
end

