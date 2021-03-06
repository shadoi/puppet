# The class that handles testing whether our providers
# actually work or not.
require 'puppet/util'

class Puppet::Provider::Confine
    include Puppet::Util

    @tests = {}

    class << self
        attr_accessor :name
    end

    def self.inherited(klass)
        name = klass.to_s.split("::").pop.downcase.to_sym
        raise "Test %s is already defined" % name if @tests.include?(name)

        klass.name = name

        @tests[name] = klass
    end

    def self.test(name)
        unless @tests[name]
            begin
                require "puppet/provider/confine/%s" % name
            rescue LoadError => detail
                unless detail.to_s.include?("no such file")
                    warn "Could not load confine test '%s': %s" % [name, detail]
                end
                # Could not find file
            end
        end
        return @tests[name]
    end

    attr_reader :values

    # Mark that this confine is used for testing binary existence.
    attr_accessor :for_binary
    def for_binary?
        for_binary
    end

    def initialize(values)
        values = [values] unless values.is_a?(Array)
        @values = values
    end

    # Provide a hook for the message when there's a failure.
    def message(value)
        ""
    end

    # Collect the results of all of them.
    def result
        values.collect { |value| pass?(value) }
    end

    # Test whether our confine matches.
    def valid?
        values.each do |value|
            unless pass?(value)
                Puppet.debug message(value)
                return false
            end
        end

        return true
    ensure
        reset
    end

    # Provide a hook for subclasses.
    def reset
    end
end
