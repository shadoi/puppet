if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server/report'
require 'puppet/client/reporter'
require 'test/unit'
require 'puppettest.rb'

class TestReportServer < Test::Unit::TestCase
	include TestPuppet
	Puppet::Util.logmethods(self)

    def mkserver
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::Report.new()
        }
        server
    end

    def mkclient(server = nil)
        server ||= mkserver()
        client = nil
        assert_nothing_raised {
            client = Puppet::Client::Reporter.new(:Report => server)
        }

        client
    end

    def test_report
        # Create a bunch of log messages in an array.
        report = Puppet::Transaction::Report.new

        10.times { |i|
            log = warning("Report test message %s" % i)
            log.tags = %w{a list of tags}
            log.tags << "tag%s" % i

            report.newlog(log)
        }

        # Now make our reporting client
        client = mkclient()

        # Now send the report
        file = nil
        assert_nothing_raised("Reporting failed") {
            file = client.report(report)
        }

        # And make sure our YAML file exists.
        assert(FileTest.exists?(file),
            "Report file did not get created")

        # And then try to reconstitute the report.
        newreport = nil
        assert_nothing_raised("Failed to load report file") {
            newreport = YAML.load(File.read(file))
        }

        # Make sure our report is valid and stuff.
        report.logs.zip(newreport.logs).each do |ol,nl|
            %w{level message time tags source}.each do |method|
                assert_equal(ol.send(method), nl.send(method),
                    "%s got changed" % method)
            end
        end
    end

    # Make sure we don't have problems with calling mkclientdir multiple
    # times.
    def test_multiple_clients
        server ||= mkserver()

        %w{hostA hostB hostC}.each do |host|
            dir = tempfile()
            assert_nothing_raised("Could not create multiple host report dirs") {
                server.send(:mkclientdir, host, dir)
            }

            assert(FileTest.directory?(dir),
                "Directory was not created")
        end
    end
end

# $Id$
