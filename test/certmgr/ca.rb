#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/sslcertificates/ca.rb'
require 'puppettest'
require 'puppettest/certificates'

class TestCA < Test::Unit::TestCase
    include PuppetTest
    def hosts
        %w{host.domain.com Other.Testing.Com}
    end
    def mkca
        Puppet::SSLCertificates::CA.new
    end
    
    def test_clean
        dirs = [:csrdir, :signeddir, :publickeydir, :privatekeydir, :certdir]
        ca = mkca
        
        hosts.each do |host|
            files = []
            dirs.each do |dir|
                dir = Puppet[dir]
                # We handle case insensitivity through downcasing
                file = File.join(dir, host.downcase + ".pem")
                File.open(file, "w") do |f|
                    f.puts "testing"
                end
                files << file
            end
            assert_nothing_raised do
                ca.clean(host)
            end
            files.each do |f|
                assert(! FileTest.exists?(f), "File %s was not deleted" % f)
            end
        end
    end
    
    def test_host2Xfile
        ca = mkca
        hosts.each do |host|
            {:signeddir => :host2certfile, :csrdir => :host2csrfile}.each do |dir, method|
                val = nil
                assert_nothing_raised do
                    val = ca.send(method, host)
                end
                assert_equal(File.join(Puppet[dir], host.downcase + ".pem"), val,
                    "incorrect response from %s" % method)
            end
        end
    end
    
    def test_list
        ca = mkca
        # Make a fake csr
        dir = Puppet[:csrdir]
        list = []
        hosts.each do |host|
            file = File.join(dir, host.downcase + ".pem")
            File.open(file, "w") { |f| f.puts "yay" }
            list << host.downcase
        end
        
        assert_equal(list.sort, ca.list.sort, "list was not correct")
    end
end

# $Id$