#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-15.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Mongrel, "after initializing" do
    confine "Mongrel is not available" => Puppet.features.mongrel?
    
    it "should not be listening" do
        Puppet::Network::HTTP::Mongrel.new.should_not be_listening
    end
end

describe Puppet::Network::HTTP::Mongrel, "when turning on listening" do
    confine "Mongrel is not available" => Puppet.features.mongrel?

    before do
        @server = Puppet::Network::HTTP::Mongrel.new
        @mock_mongrel = mock('mongrel')
        @mock_mongrel.stubs(:run)
        @mock_mongrel.stubs(:register)
        Mongrel::HttpServer.stubs(:new).returns(@mock_mongrel)

        @mock_puppet_mongrel = mock('puppet_mongrel')
        Puppet::Network::HTTPServer::Mongrel.stubs(:new).returns(@mock_puppet_mongrel)

        @listen_params = { :address => "127.0.0.1", :port => 31337,
            :handlers => [ :node, :catalog ], :protocols => [ :rest, :xmlrpc ],
            :xmlrpc_handlers => [ :status, :fileserver ]
        }
    end
    
    it "should fail if already listening" do
        @server.listen(@listen_params)
        Proc.new { @server.listen(@listen_params) }.should raise_error(RuntimeError)
    end
    
    it "should require at least one handler" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :handlers == k}) }.should raise_error(ArgumentError)
    end
    
    it "should require at least one protocol" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :protocols == k}) }.should raise_error(ArgumentError)
    end
    
    it "should require a listening address to be specified" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :address == k})}.should raise_error(ArgumentError)
    end
    
    it "should require a listening port to be specified" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :port == k})}.should raise_error(ArgumentError)
    end
    
    it "should order a mongrel server to start" do
        @mock_mongrel.expects(:run)
        @server.listen(@listen_params)
    end
    
    it "should tell mongrel to listen on the specified address and port" do
        Mongrel::HttpServer.expects(:new).with("127.0.0.1", 31337).returns(@mock_mongrel)
        @server.listen(@listen_params)
    end
    
    it "should be listening" do
        Mongrel::HttpServer.expects(:new).returns(@mock_mongrel)
        @server.listen(@listen_params)
        @server.should be_listening
    end

    describe "when providing REST services" do
        it "should instantiate a handler for each protocol+handler pair to configure web server routing" do
            @listen_params[:protocols].each do |protocol|
                @listen_params[:handlers].each do |handler|
                    @mock_mongrel.expects(:register)
                end
            end
            @server.listen(@listen_params)        
        end
        
        it "should use a Mongrel + REST class to configure Mongrel when REST services are requested" do
            @server.expects(:class_for_protocol).with(:rest).at_least_once.returns(Puppet::Network::HTTP::MongrelREST)
            @server.listen(@listen_params)
        end
    end

    describe "when providing XMLRPC services" do
        it "should do nothing if no xmlrpc handlers have been provided" do
            Puppet::Network::HTTPServer::Mongrel.expects(:new).never
            @server.listen(@listen_params.merge(:xmlrpc_handlers => []))
        end

        it "should create an instance of the existing Mongrel http server with the right handlers" do
            Puppet::Network::HTTPServer::Mongrel.expects(:new).with([:status, :master]).returns(@mock_puppet_mongrel)
            @server.listen(@listen_params.merge(:xmlrpc_handlers => [:status, :master]))
        end

        it "should register the Mongrel server instance at /RPC2" do
            @mock_mongrel.expects(:register).with("/RPC2", @mock_puppet_mongrel)

            @server.listen(@listen_params.merge(:xmlrpc_handlers => [:status, :master]))
        end
    end
    
    it "should fail if services from an unknown protocol are requested" do
        Proc.new { @server.listen(@listen_params.merge(:protocols => [ :foo ]))}.should raise_error(ArgumentError)
    end
end

describe Puppet::Network::HTTP::Mongrel, "when turning off listening" do
    confine "Mongrel is not available" => Puppet.features.mongrel?
    
    before do
        @mock_mongrel = mock('mongrel httpserver')
        @mock_mongrel.stubs(:run)
        @mock_mongrel.stubs(:register)
        Mongrel::HttpServer.stubs(:new).returns(@mock_mongrel)
        @server = Puppet::Network::HTTP::Mongrel.new        
        @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => [ :node, :catalog ], :protocols => [ :rest ] }
    end
    
    it "should fail unless listening" do
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
    
    it "should order mongrel server to stop" do
        @server.listen(@listen_params)
        @mock_mongrel.expects(:stop)
        @server.unlisten
    end
    
    it "should not be listening" do
        @server.listen(@listen_params)
        @mock_mongrel.stubs(:stop)
        @server.unlisten
        @server.should_not be_listening
    end
end
