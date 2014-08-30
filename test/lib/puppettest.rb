# Add .../test/lib
testlib = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(testlib) unless $LOAD_PATH.include?(testlib)
# Add .../lib
mainlib = File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))
$LOAD_PATH.unshift(mainlib) unless $LOAD_PATH.include?(mainlib)

require 'puppet'

# include any gems in vendor/gems
Dir["#{mainlib}/../vendor/gems/**"].each do |path|
    libpath = File.join(path, "lib")
    if File.directory?(libpath)
        $LOAD_PATH.unshift(libpath)
    else
        $LOAD_PATH.unshift(path)
    end
end

require 'mocha'

# Only load the test/unit class if we're not in the spec directory.
# Else we get the bogus 'no tests, no failures' message.
unless Dir.getwd =~ /spec/
    require 'test/unit'
end

# Yay; hackish but it works
if ARGV.include?("-d")
    ARGV.delete("-d")
    $console = true
end

# Some monkey-patching to allow us to test private methods.
class Class
    def publicize_methods(*methods)
        saved_private_instance_methods = methods.empty? ? self.private_instance_methods : methods

        self.class_eval { public(*saved_private_instance_methods) }
        yield
        self.class_eval { private(*saved_private_instance_methods) }
    end
end

module PuppetTest
    # These need to be here for when rspec tests use these
    # support methods.
    @@tmpfiles = []

    # Munge cli arguments, so we can enable debugging if we want
    # and so we can run just specific methods.
    def self.munge_argv
        require 'getoptlong'

        result = GetoptLong.new(
            [ "--debug",	"-d",			GetoptLong::NO_ARGUMENT ],
            [ "--resolve",	"-r",			GetoptLong::REQUIRED_ARGUMENT ],
            [ "-n",			                GetoptLong::REQUIRED_ARGUMENT ],
            [ "--help",		"-h",			GetoptLong::NO_ARGUMENT ]
        )

        usage = "USAGE: TESTOPTS='[-n <method> -n <method> ...] [-d]' rake [target] [target] ..."

        opts = []

        dir = method = nil
        result.each { |opt,arg|
            case opt
            when "--resolve"
                dir, method = arg.split(",")
            when "--debug"
                $puppet_debug = true
                Puppet::Util::Log.level = :debug
                Puppet::Util::Log.newdestination(:console)
            when "--help"
                puts usage
                exit
            else
                opts << opt << arg
            end
        }
        suites = nil

        args = ARGV.dup

        # Reset the options, so the test suite can deal with them (this is
        # what makes things like '-n' work).
        opts.each { |o| ARGV << o }

        return args
    end

    # Find the root of the Puppet tree; this is not the test directory, but
    # the parent of that dir.
    def basedir(*list)
        unless defined? @@basedir
            Dir.chdir(File.dirname(__FILE__)) do
                @@basedir = File.dirname(File.dirname(Dir.getwd))
            end
        end
        if list.empty?
            @@basedir
        else
            File.join(@@basedir, *list)
        end
    end

    def datadir(*list)
        File.join(basedir, "test", "data", *list)
    end

    def exampledir(*args)
        unless defined? @@exampledir
            @@exampledir = File.join(basedir, "examples")
        end

        if args.empty?
            return @@exampledir
        else
            return File.join(@@exampledir, *args)
        end
    end

    module_function :basedir, :datadir, :exampledir

    def cleanup(&block)
        @@cleaners << block
    end

    # Rails clobbers RUBYLIB, thanks
    def libsetup
        curlibs = ENV["RUBYLIB"].split(":")
        $:.reject do |dir| dir =~ /^\/usr/ end.each do |dir|
            unless curlibs.include?(dir)
                curlibs << dir
            end
        end

        ENV["RUBYLIB"] = curlibs.join(":")
    end

    def logcollector
        collector = []
        Puppet::Util::Log.newdestination(collector)
        cleanup do
            Puppet::Util::Log.close(collector)
        end
        collector
    end

    def rake?
        $0 =~ /test_loader/
    end

    # Redirect stdout and stderr
    def redirect
        @stderr = tempfile
        @stdout = tempfile
        $stderr = File.open(@stderr, "w")
        $stdout = File.open(@stdout, "w")

        cleanup do
            $stderr = STDERR
            $stdout = STDOUT
        end
    end

    def setup
        @memoryatstart = Puppet::Util.memory
        if defined? @@testcount
            @@testcount += 1
        else
            @@testcount = 0
        end

        @configpath = File.join(tmpdir,
            "configdir" + @@testcount.to_s + "/"
        )

        unless defined? $user and $group
            $user = nonrootuser().uid.to_s
            $group = nonrootgroup().gid.to_s
        end

        Puppet.settings.clear
        Puppet[:user] = $user
        Puppet[:group] = $group

        Puppet[:confdir] = @configpath
        Puppet[:vardir] = @configpath

        unless File.exists?(@configpath)
            Dir.mkdir(@configpath)
        end

        @@tmpfiles << @configpath << tmpdir()
        @@tmppids = []

        @@cleaners = []

        @logs = []

        # If we're running under rake, then disable debugging and such.
        #if rake? or ! Puppet[:debug]
        #if defined?($puppet_debug) or ! rake?
            if textmate?
                Puppet[:color] = false
            end
            Puppet::Util::Log.newdestination(@logs)
            if defined? $console
                Puppet.info @method_name
                Puppet::Util::Log.newdestination(:console)
                Puppet[:trace] = true
            end
            Puppet::Util::Log.level = :debug
            #$VERBOSE = 1
        #else
        #    Puppet::Util::Log.close
        #    Puppet::Util::Log.newdestination(@logs)
        #    Puppet[:httplog] = tempfile()
        #end

        Puppet[:ignoreschedules] = true

        #@start = Time.now
    end

    def tempfile
        if defined? @@tmpfilenum
            @@tmpfilenum += 1
        else
            @@tmpfilenum = 1
        end

        f = File.join(self.tmpdir(), "tempfile_" + @@tmpfilenum.to_s)
        @@tmpfiles ||= []
        @@tmpfiles << f
        return f
    end

    def textmate?
        if ENV["TM_FILENAME"]
            return true
        else
            return false
        end
    end

    def tstdir
        dir = tempfile()
        Dir.mkdir(dir)
        return dir
    end

    def tmpdir
        unless defined? @tmpdir and @tmpdir
            @tmpdir = case Facter["operatingsystem"].value
                      when "Darwin": "/private/tmp"
                      when "SunOS": "/var/tmp"
                      else
                            "/tmp"
                      end


            @tmpdir = File.join(@tmpdir, "puppettesting" + Process.pid.to_s)

            unless File.exists?(@tmpdir)
                FileUtils.mkdir_p(@tmpdir)
                File.chmod(01777, @tmpdir)
            end
        end
        @tmpdir
    end

    def remove_tmp_files
        @@tmpfiles.each { |file|
            unless file =~ /tmp/
                puts "Not deleting tmpfile %s" % file
                next
            end
            if FileTest.exists?(file)
                system("chmod -R 755 %s" % file)
                system("rm -rf %s" % file)
            end
        }
        @@tmpfiles.clear
    end

    def teardown
        #@stop = Time.now
        #File.open("/tmp/test_times.log", ::File::WRONLY|::File::CREAT|::File::APPEND) { |f| f.puts "%0.4f %s %s" % [@stop - @start, @method_name, self.class] }
        @@cleaners.each { |cleaner| cleaner.call() }

        remove_tmp_files

        @@tmppids.each { |pid|
            %x{kill -INT #{pid} 2>/dev/null}
        }

        @@tmppids.clear

        Puppet::Util::Storage.clear
        Puppet.clear
        Puppet.settings.clear
        Puppet::Util::Cacher.invalidate

        @memoryatend = Puppet::Util.memory
        diff = @memoryatend - @memoryatstart

        if diff > 1000
            Puppet.info "%s#%s memory growth (%s to %s): %s" %
                [self.class, @method_name, @memoryatstart, @memoryatend, diff]
        end

        # reset all of the logs
        Puppet::Util::Log.close
        @logs.clear

        # Just in case there are processes waiting to die...
        require 'timeout'

        begin
            Timeout::timeout(5) do
                Process.waitall
            end
        rescue Timeout::Error
            # just move on
        end
    end

    def logstore
        @logs = []
        Puppet::Util::Log.newdestination(@logs)
    end
end

require 'puppettest/support'
require 'puppettest/filetesting'
require 'puppettest/fakes'
require 'puppettest/exetest'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'puppettest/testcase'

