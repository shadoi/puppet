Puppet::Type.type(:service).provide :base do
    desc "The simplest form of service support.  You have to specify
        enough about your service for this to work; the minimum you can specify
        is a binary for starting the process, and this same binary will be searched
        for in the process table to stop the service.  It is preferable to
        specify start, stop, and status commands, akin to how you would do
        so using ``init``."

    # Execute a command.  Basically just makes sure it exits with a 0
    # code.
    def execute(type, cmd)
        self.debug "Executing %s" % cmd.inspect
        output = %x(#{cmd} 2>&1)
        unless $? == 0
            @model.fail "Could not %s %s: %s" %
                [type, self.name, output.chomp]
        end
    end

    # Get the process ID for a running process. Requires the 'pattern'
    # parameter.
    def getpid
        unless @model[:pattern]
            @model.fail "Either a stop command or a pattern must be specified"
        end
        ps = Facter["ps"].value
        warning ps.inspect
        unless ps and ps != ""
            @model.fail(
                "You must upgrade Facter to a version that includes 'ps'"
            )
        end
        regex = Regexp.new(@model[:pattern])
        self.debug "Executing '#{ps}'"
        IO.popen(ps) { |table|
            table.each { |line|
                if regex.match(line)
                    ary = line.sub(/^\s+/, '').split(/\s+/)
                    return ary[1]
                end
            }
        }

        return nil
    end

    # Basically just a synonym for restarting.  Used to respond
    # to events.
    def refresh
        self.restart
    end

    # How to restart the process.
    def restart
        if @model[:restart] or self.respond_to?(:restartcmd)
            cmd = @model[:restart] || self.restartcmd
            self.execute("restart", cmd)
        else
            self.stop
            self.start
        end
    end

    # Check if the process is running.  Prefer the 'status' parameter,
    # then 'statuscmd' method, then look in the process table.  We give
    # the object the option to not return a status command, which might
    # happen if, for instance, it has an init script (and thus responds to
    # 'statuscmd') but does not have 'hasstatus' enabled.
    def status
        if @model[:status] or (
            self.respond_to?(:statuscmd) and self.statuscmd
        )
            cmd = @model[:status] || self.statuscmd
            self.debug "Executing %s" % cmd.inspect
            output = %x(#{cmd} 2>&1)
            self.debug "%s status returned %s" %
                [self.name, output.inspect]
            if $? == 0
                return :running
            else
                return :stopped
            end
        elsif pid = self.getpid
            self.debug "PID is %s" % pid
            return :running
        else
            return :stopped
        end
    end

    # Run the 'start' parameter command, or the specified 'startcmd'.
    def start
        cmd = @model[:start] || self.startcmd
        self.execute("start", cmd)
    end

    # The command used to start.  Generated if the 'binary' argument
    # is passed.
    def startcmd
        if @model[:binary]
            return @model[:binary]
        else
            raise Puppet::Error,
                "Services must specify a start command or a binary"
        end
    end

    # Stop the service.  If a 'stop' parameter is specified, it
    # takes precedence; otherwise checks if the object responds to
    # a 'stopcmd' method, and if so runs that; otherwise, looks
    # for the process in the process table.
    # This method will generally not be overridden by submodules.
    def stop
        if @model[:stop]
            return @model[:stop]
        elsif self.respond_to?(:stopcmd)
            self.execute("stop", self.stopcmd)
        else
            pid = getpid
            unless pid
                self.info "%s is not running" % self.name
                return false
            end
            output = %x(kill #{pid} 2>&1)
            if $? != 0
                @model.fail "Could not kill %s, PID %s: %s" %
                        [self.name, pid, output]
            end
            return true
        end
    end
end

# $Id$