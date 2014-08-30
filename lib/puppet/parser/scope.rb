# The scope class, which handles storing and retrieving variables and types and
# such.

require 'puppet/parser/parser'
require 'puppet/parser/templatewrapper'
require 'puppet/transportable'
require 'strscan'

class Puppet::Parser::Scope
    require 'puppet/parser/resource'

    AST = Puppet::Parser::AST

    Puppet::Util.logmethods(self)

    include Enumerable
    include Puppet::Util::Errors
    attr_accessor :parent, :level, :parser, :source, :resource
    attr_accessor :base, :keyword, :nodescope
    attr_accessor :top, :translated, :compiler

    # A demeterific shortcut to the catalog.
    def catalog
        compiler.catalog
    end

    # Proxy accessors
    def host
        @compiler.node.name
    end

    def interpreter
        @compiler.interpreter
    end

    # Is the value true?  This allows us to control the definition of truth
    # in one place.
    def self.true?(value)
        if value == false or value == "" or value == :undef
            return false
        else
            return true
        end
    end

    # Add to our list of namespaces.
    def add_namespace(ns)
        return false if @namespaces.include?(ns)
        if @namespaces == [""]
            @namespaces = [ns]
        else
            @namespaces << ns
        end
    end

    # Are we the top scope?
    def topscope?
        @level == 1
    end

    def findclass(name)
        @namespaces.each do |namespace|
            if r = parser.findclass(namespace, name)
                return r
            end
        end
        return nil
    end

    def finddefine(name)
        @namespaces.each do |namespace|
            if r = parser.finddefine(namespace, name)
                return r
            end
        end
        return nil
    end

    def findresource(string, name = nil)
        compiler.findresource(string, name)
    end

    # Initialize our new scope.  Defaults to having no parent.
    def initialize(hash = {})
        if hash.include?(:namespace)
            if n = hash[:namespace]
                @namespaces = [n]
            end
            hash.delete(:namespace)
        else
            @namespaces = [""]
        end
        hash.each { |name, val|
            method = name.to_s + "="
            if self.respond_to? method
                self.send(method, val)
            else
                raise Puppet::DevError, "Invalid scope argument %s" % name
            end
        }

        @tags = []

        # The symbol table for this scope.  This is where we store variables.
        @symtable = {}

        # All of the defaults set for types.  It's a hash of hashes,
        # with the first key being the type, then the second key being
        # the parameter.
        @defaults = Hash.new { |dhash,type|
            dhash[type] = {}
        }
    end

    # Collect all of the defaults set at any higher scopes.
    # This is a different type of lookup because it's additive --
    # it collects all of the defaults, with defaults in closer scopes
    # overriding those in later scopes.
    def lookupdefaults(type)
        values = {}

        # first collect the values from the parents
        unless parent.nil?
            parent.lookupdefaults(type).each { |var,value|
                values[var] = value
            }
        end

        # then override them with any current values
        # this should probably be done differently
        if @defaults.include?(type)
            @defaults[type].each { |var,value|
                values[var] = value
            }
        end

        #Puppet.debug "Got defaults for %s: %s" %
        #    [type,values.inspect]
        return values
    end

    # Look up a defined type.
    def lookuptype(name)
        finddefine(name) || findclass(name)
    end

    def lookup_qualified_var(name, usestring)
        parts = name.split(/::/)
        shortname = parts.pop
        klassname = parts.join("::")
        klass = findclass(klassname)
        unless klass
            raise Puppet::ParseError, "Could not find class %s" % klassname
        end
        unless kscope = compiler.class_scope(klass)
            raise Puppet::ParseError, "Class %s has not been evaluated so its variables cannot be referenced" % klass.classname
        end
        return kscope.lookupvar(shortname, usestring)
    end

    private :lookup_qualified_var

    # Look up a variable.  The simplest value search we do.  Default to returning
    # an empty string for missing values, but support returning a constant.
    def lookupvar(name, usestring = true)
        # If the variable is qualified, then find the specified scope and look the variable up there instead.
        if name =~ /::/
            return lookup_qualified_var(name, usestring)
        end
        # We can't use "if @symtable[name]" here because the value might be false
        if @symtable.include?(name)
            if usestring and @symtable[name] == :undef
                return ""
            else
                return @symtable[name]
            end
        elsif self.parent
            return parent.lookupvar(name, usestring)
        elsif usestring
            return ""
        else
            return :undefined
        end
    end

    def namespaces
        @namespaces.dup
    end

    # Create a new scope and set these options.
    def newscope(options = {})
        compiler.newscope(self, options)
    end

    # Is this class for a node?  This is used to make sure that
    # nodes and classes with the same name conflict (#620), which
    # is required because of how often the names are used throughout
    # the system, including on the client.
    def nodescope?
        self.nodescope
    end

    # We probably shouldn't cache this value...  But it's a lot faster
    # than doing lots of queries.
    def parent
        unless defined?(@parent)
            @parent = compiler.parent(self)
        end
        @parent
    end

    # Return the list of scopes up to the top scope, ordered with our own first.
    # This is used for looking up variables and defaults.
    def scope_path
        if parent
            [self, parent.scope_path].flatten.compact
        else
            [self]
        end
    end

    # Set defaults for a type.  The typename should already be downcased,
    # so that the syntax is isolated.  We don't do any kind of type-checking
    # here; instead we let the resource do it when the defaults are used.
    def setdefaults(type, params)
        table = @defaults[type]

        # if we got a single param, it'll be in its own array
        params = [params] unless params.is_a?(Array)

        params.each { |param|
            #Puppet.debug "Default for %s is %s => %s" %
            #    [type,ary[0].inspect,ary[1].inspect]
            if table.include?(param.name)
                raise Puppet::ParseError.new("Default already defined for %s { %s }; cannot redefine" % [type, param.name], param.line, param.file)
            end
            table[param.name] = param
        }
    end

    # Set a variable in the current scope.  This will override settings
    # in scopes above, but will not allow variables in the current scope
    # to be reassigned.
    def setvar(name,value, file = nil, line = nil)
        #Puppet.debug "Setting %s to '%s' at level %s" %
        #    [name.inspect,value,self.level]
        if @symtable.include?(name)
            error = Puppet::ParseError.new("Cannot reassign variable %s" % name)
            if file
                error.file = file
            end
            if line
                error.line = line
            end
            raise error
        end
        @symtable[name] = value
    end

    # Return an interpolated string.
    def strinterp(string, file = nil, line = nil)
        # Most strings won't have variables in them.
        ss = StringScanner.new(string)
        out = ""
        while not ss.eos?
            if ss.scan(/^\$\{((\w*::)*\w+)\}|^\$((\w*::)*\w+)/)
                # If it matches the backslash, then just retun the dollar sign.
                if ss.matched == '\\$'
                    out << '$'
                else # look the variable up
                    out << lookupvar(ss[1] || ss[3]).to_s || ""
                end
            elsif ss.scan(/^\\(.)/)
                # Puppet.debug("Got escape: pos:%d; m:%s" % [ss.pos, ss.matched])
                case ss[1]
                when 'n'
                    out << "\n"
                when 't'
                    out << "\t"
                when 's'
                    out << " "
                when '\\'
                    out << '\\'
                when '$'
                    out << '$'
                else
                    str = "Unrecognised escape sequence '#{ss.matched}'"
                    if file
                        str += " in file %s" % file
                    end
                    if line
                        str += " at line %s" % line
                    end
                    Puppet.warning str
                    out << ss.matched
                end
            elsif ss.scan(/^\$/)
                out << '$'
            elsif ss.scan(/^\\\n/) # an escaped carriage return
                next
            else
                tmp = ss.scan(/[^\\$]+/)
                # Puppet.debug("Got other: pos:%d; m:%s" % [ss.pos, tmp])
                unless tmp
                    error = Puppet::ParseError.new("Could not parse string %s" %
                        string.inspect)
                    {:file= => file, :line= => line}.each do |m,v|
                        error.send(m, v) if v
                    end
                    raise error
                end
                out << tmp
            end
        end

        return out
    end

    # Return the tags associated with this scope.  It's basically
    # just our parents' tags, plus our type.  We don't cache this value
    # because our parent tags might change between calls.
    def tags
        resource.tags
    end

    # Used mainly for logging
    def to_s
        "Scope(%s)" % @resource.to_s
    end

    # Undefine a variable; only used for testing.
    def unsetvar(var)
        if @symtable.include?(var)
            @symtable.delete(var)
        end
    end
end
