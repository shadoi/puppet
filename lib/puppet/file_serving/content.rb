#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/file_base'
require 'puppet/file_serving/indirection_hooks'

# A class that handles retrieving file contents.
# It only reads the file when its content is specifically
# asked for.
class Puppet::FileServing::Content < Puppet::FileServing::FileBase
    extend Puppet::Indirector
    indirects :file_content, :extend => Puppet::FileServing::IndirectionHooks

    attr_reader :path

    # Read the content of our file in.
    def content
        # This stat can raise an exception, too.
        raise(ArgumentError, "Cannot read the contents of links unless following links") if stat().ftype == "symlink"

        ::File.read(full_path())
    end

    # Just return the file contents as the yaml.  This allows us to
    # avoid escaping or any such thing.  LAK:NOTE Not really sure how
    # this will behave if the file contains yaml...  I think the far
    # side needs to understand that it's a plain string.
    def to_yaml
        content
    end
end
