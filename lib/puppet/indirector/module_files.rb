#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util/uri_helper'
require 'puppet/indirector/terminus'
require 'puppet/file_serving/configuration'
require 'puppet/file_serving/fileset'
require 'puppet/file_serving/terminus_helper'

# Look files up in Puppet modules.
class Puppet::Indirector::ModuleFiles < Puppet::Indirector::Terminus
    include Puppet::Util::URIHelper
    include Puppet::FileServing::TerminusHelper

    # Is the client allowed access to this key with this method?
    def authorized?(method, key, options = {})
        return false unless [:find, :search].include?(method)

        uri = key2uri(key)

        # Make sure our file path starts with /modules, so that we authorize
        # against the 'modules' mount.
        path = uri.path =~ /^\/modules/ ? uri.path : "/modules" + uri.path

        configuration.authorized?(path, :node => options[:node], :ipaddress => options[:ipaddress])
    end

    # Find our key in a module.
    def find(key, options = {})
        return nil unless path = find_path(key, options)

        result = model.new(key, :path => path)
        result.links = options[:links] if options[:links]
        return result
    end

    # Try to find our module.
    def find_module(module_name, node_name)
        Puppet::Module::find(module_name, environment(node_name))
    end

    # Search for a list of files.
    def search(key, options = {})
        return nil unless path = find_path(key, options)
        path2instances(key, path, options)
    end

    private

    # Our fileserver configuration, if needed.
    def configuration
        Puppet::FileServing::Configuration.create
    end

    # Determine the environment to use, if any.
    def environment(node_name)
        if node_name and node = Puppet::Node.find(node_name)
            node.environment
        else
            Puppet::Node::Environment.new.name
        end
    end

    # The abstracted method for turning a key into a path; used by both :find and :search.
    def find_path(key, options)
        uri = key2uri(key)

        # Strip off /modules if it's there -- that's how requests get routed to this terminus.
        # Also, strip off the leading slash if present.
        module_name, relative_path = uri.path.sub(/^\/modules\b/, '').sub(%r{^/}, '').split(File::Separator, 2)

        # And use the environment to look up the module.
        return nil unless mod = find_module(module_name, options[:node])

        path = File.join(mod.files, relative_path)

        return nil unless FileTest.exists?(path)

        return path
    end
end
