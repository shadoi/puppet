require 'mongrel' if Puppet.features.mongrel?

require 'puppet/network/http/mongrel/rest'

class Puppet::Network::HTTP::Mongrel
    def initialize(args = {})
        @listening = false
    end

    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].empty?
        raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        raise "Mongrel server is already listening" if listening?

        @protocols = args[:protocols]
        @handlers = args[:handlers]
        @xmlrpc_handlers = args[:xmlrpc_handlers]
        @server = Mongrel::HttpServer.new(args[:address], args[:port])
        setup_handlers

        @listening = true
        @server.run
    end

    def unlisten
        raise "Mongrel server is not listening" unless listening?
        @server.stop
        @server = nil
        @listening = false
    end

    def listening?
        @listening
    end

  private

    def setup_handlers
        @protocols.each do |protocol|
            next if protocol == :xmlrpc
            klass = class_for_protocol(protocol)
            @handlers.each do |handler|
                @server.register('/' + handler.to_s, klass.new(:server => @server, :handler => handler))
                @server.register('/' + handler.to_s + 's', klass.new(:server => @server, :handler => handler))
            end
        end

        if @protocols.include?(:xmlrpc) and ! @xmlrpc_handlers.empty?
            setup_xmlrpc_handlers
        end
    end

    # Use our existing code to provide the xmlrpc backward compatibility.
    def setup_xmlrpc_handlers
        @server.register('/RPC2', Puppet::Network::HTTPServer::Mongrel.new(@xmlrpc_handlers))
    end

    def class_for_protocol(protocol)
        return Puppet::Network::HTTP::MongrelREST if protocol.to_sym == :rest
        raise ArgumentError, "Unknown protocol [#{protocol}]."
    end
end
