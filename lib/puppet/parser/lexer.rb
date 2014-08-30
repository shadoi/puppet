# the scanner/lexer

require 'strscan'
require 'puppet'


module Puppet
    class LexError < RuntimeError; end
end

module Puppet::Parser; end

class Puppet::Parser::Lexer
    attr_reader :last, :file

    attr_accessor :line, :indefine

    # Our base token class.
    class Token
        attr_accessor :regex, :name, :string, :skip, :incr_line, :skip_text

        def initialize(regex, name)
            if regex.is_a?(String)
                @name, @string = name, regex
                @regex = Regexp.new(Regexp.escape(@string))
            else
                @name, @regex = name, regex
            end
        end

        def skip?
            self.skip
        end

        def to_s
            if self.string
                @string
            else
                @name.to_s
            end
        end
    end

    # Maintain a list of tokens.
    class TokenList
        attr_reader :regex_tokens, :string_tokens

        def [](name)
            @tokens[name]
        end

        # Create a new token.
        def add_token(name, regex, options = {}, &block)
            token = Token.new(regex, name)
            raise(ArgumentError, "Token %s already exists" % name) if @tokens.include?(name)
            @tokens[token.name] = token
            if token.string
                @string_tokens << token
                @tokens_by_string[token.string] = token
            else
                @regex_tokens << token
            end

            options.each do |name, option|
                token.send(name.to_s + "=", option)
            end

            token.meta_def(:convert, &block) if block_given?

            token
        end

        def initialize
            @tokens = {}
            @regex_tokens = []
            @string_tokens = []
            @tokens_by_string = {}
        end

        # Look up a token by its value, rather than name.
        def lookup(string)
            @tokens_by_string[string]
        end

        # Define more tokens.
        def add_tokens(hash)
            hash.each do |regex, name|
                add_token(name, regex)
            end
        end

        # Sort our tokens by length, so we know once we match, we're done.
        # This helps us avoid the O(n^2) nature of token matching.
        def sort_tokens
            @string_tokens.sort! { |a, b| b.string.length <=> a.string.length }
        end
    end

    TOKENS = TokenList.new
    TOKENS.add_tokens(
        '[' => :LBRACK,
        ']' => :RBRACK,
        '{' => :LBRACE,
        '}' => :RBRACE,
        '(' => :LPAREN,
        ')' => :RPAREN,
        '=' => :EQUALS,
        '==' => :ISEQUAL,
        '>=' => :GREATEREQUAL,
        '>' => :GREATERTHAN,
        '<' => :LESSTHAN,
        '<=' => :LESSEQUAL,
        '!=' => :NOTEQUAL,
        '!' => :NOT,
        ',' => :COMMA,
        '.' => :DOT,
        ':' => :COLON,
        '@' => :AT,
        '<<|' => :LLCOLLECT,
        '|>>' => :RRCOLLECT,
        '<|' => :LCOLLECT,
        '|>' => :RCOLLECT,
        ';' => :SEMIC,
        '?' => :QMARK,
        '\\' => :BACKSLASH,
        '=>' => :FARROW,
        '+>' => :PARROW,
        %r{([a-z][-\w]*::)+[a-z][-\w]*} => :CLASSNAME,
        %r{((::){0,1}[A-Z][-\w]*)+} => :CLASSREF
    )

    TOKENS.add_tokens "Whatever" => :DQTEXT, "Nomatter" => :SQTEXT, "alsonomatter" => :BOOLEAN

    TOKENS.add_token :NAME, %r{[a-z][-\w]*} do |lexer, value|
        string_token = self
        # we're looking for keywords here
        if tmp = KEYWORDS.lookup(value)
            string_token = tmp
            if [:TRUE, :FALSE].include?(string_token.name)
                value = eval(value)
                string_token = TOKENS[:BOOLEAN]
            end
        end
        [string_token, value]
    end

    TOKENS.add_token :NUMBER, %r{[0-9]+} do |lexer, value|
        [TOKENS[:NAME], value]
    end

    TOKENS.add_token :COMMENT, %r{#.*}, :skip => true

    TOKENS.add_token :RETURN, "\n", :skip => true, :incr_line => true, :skip_text => true

    TOKENS.add_token :SQUOTE, "'" do |lexer, value|
        value = lexer.slurpstring(value)
        [TOKENS[:SQTEXT], value]
    end

    TOKENS.add_token :DQUOTE, '"' do |lexer, value|
        value = lexer.slurpstring(value)
        [TOKENS[:DQTEXT], value]
    end

    TOKENS.add_token :VARIABLE, %r{\$(\w*::)*\w+} do |lexer, value|
        value = value.sub(/^\$/, '')
        [self, value]
    end

    TOKENS.sort_tokens

    @@pairs = {
        "{" => "}",
        "(" => ")",
        "[" => "]",
        "<|" => "|>",
        "<<|" => "|>>"
    }

    KEYWORDS = TokenList.new

    KEYWORDS.add_tokens(
        "case" => :CASE,
        "class" => :CLASS,
        "default" => :DEFAULT,
        "define" => :DEFINE,
        "import" => :IMPORT,
        "if" => :IF,
        "elsif" => :ELSIF,
        "else" => :ELSE,
        "inherits" => :INHERITS,
        "node" => :NODE,
        "and"  => :AND,
        "or"   => :OR,
        "undef"   => :UNDEF,
        "false" => :FALSE,
        "true" => :TRUE
    )

    def clear
        initvars
    end

    def expected
        return nil if @expected.empty?
        name = @expected[-1]
        raise "Could not find expected token %s" % name unless token = TOKENS.lookup(name)

        return token
    end

    # scan the whole file
    # basically just used for testing
    def fullscan
        array = []

        self.scan { |token, str|
            # Ignore any definition nesting problems
            @indefine = false
            array.push([token,str])
        }
        return array
    end

    # this is probably pretty damned inefficient...
    # it'd be nice not to have to load the whole file first...
    def file=(file)
        @file = file
        @line = 1
        File.open(file) { |of|
            str = ""
            of.each { |line| str += line }
            @scanner = StringScanner.new(str)
        }
    end

    def find_string_token
        matched_token = value = nil

        # We know our longest string token is three chars, so try each size in turn
        # until we either match or run out of chars.  This way our worst-case is three
        # tries, where it is otherwise the number of string chars we have.  Also,
        # the lookups are optimized hash lookups, instead of regex scans.
        [3, 2, 1].each do |i|
            str = @scanner.peek(i)
            if matched_token = TOKENS.lookup(str)
                value = @scanner.scan(matched_token.regex)
                break
            end
        end

        return matched_token, value
    end

    # Find the next token that matches a regex.  We look for these first.
    def find_regex_token
        @regex += 1
        matched_token = nil
        value = ""
        length = 0

        # I tried optimizing based on the first char, but it had
        # a slightly negative affect and was a good bit more complicated.
        TOKENS.regex_tokens.each do |token|
            next unless match_length = @scanner.match?(token.regex)

            # We've found a longer match
            if match_length > length
                value = @scanner.scan(token.regex)
                length = value.length
                matched_token = token
            end
        end

        return matched_token, value
    end

    # Find the next token, returning the string and the token.
    def find_token
        @find += 1
        matched_token, value = find_regex_token

        unless matched_token
            matched_token, value = find_string_token
        end

        return matched_token, value
    end

    def indefine?
        if defined? @indefine
            @indefine
        else
            false
        end
    end

    def initialize
        @find = 0
        @regex = 0
        initvars()
    end

    def initvars
        @line = 1
        @previous_token = nil
        @scanner = nil
        @file = nil
        # AAARRGGGG! okay, regexes in ruby are bloody annoying
        # no one else has "\n" =~ /\s/
        @skip = %r{[ \t]+}

        @namestack = []
        @indefine = false
        @expected = []
    end

    # Make any necessary changes to the token and/or value.
    def munge_token(token, value)
        @line += 1 if token.incr_line

        skip() if token.skip_text

        return if token.skip

        token, value = token.convert(self, value) if token.respond_to?(:convert)

        return unless token

        return token, value
    end

    # Go up one in the namespace.
    def namepop
        @namestack.pop
    end

    # Collect the current namespace.
    def namespace
        @namestack.join("::")
    end

    # This value might have :: in it, but we don't care -- it'll be
    # handled normally when joining, and when popping we want to pop
    # this full value, however long the namespace is.
    def namestack(value)
        @namestack << value
    end

    def rest
        @scanner.rest
    end

    # this is the heart of the lexer
    def scan
        #Puppet.debug("entering scan")
        raise Puppet::LexError.new("Invalid or empty string") unless @scanner

        # Skip any initial whitespace.
        skip()

        until @scanner.eos? do
            yielded = false
            matched_token, value = find_token

            # error out if we didn't match anything at all
            if matched_token.nil?
                nword = nil
                # Try to pull a 'word' out of the remaining string.
                if @scanner.rest =~ /^(\S+)/
                    nword = $1
                elsif @scanner.rest =~ /^(\s+)/
                    nword = $1
                else
                    nword = @scanner.rest
                end
                raise "Could not match '%s'" % nword
            end

            final_token, value = munge_token(matched_token, value)

            next unless final_token

            if match = @@pairs[value] and final_token.name != :DQUOTE and final_token.name != :SQUOTE
                @expected << match
            elsif exp = @expected[-1] and exp == value and final_token.name != :DQUOTE and final_token.name != :SQUOTE
                @expected.pop
            end

            yield [final_token.name, value]

            if @previous_token
                namestack(value) if @previous_token.name == :CLASS

                if @previous_token.name == :DEFINE
                    if indefine?
                        msg = "Cannot nest definition %s inside %s" % [value, @indefine]
                        self.indefine = false
                        raise Puppet::ParseError, msg
                    end

                    @indefine = value
                end
            end

            @previous_token = final_token
            skip()
        end
        @scanner = nil

        # This indicates that we're done parsing.
        yield [false,false]
    end

    # Skip any skipchars in our remaining string.
    def skip
        @scanner.skip(@skip)
    end

    # we've encountered an opening quote...
    # slurp in the rest of the string and return it
    def slurpstring(quote)
        # we search for the next quote that isn't preceded by a
        # backslash; the caret is there to match empty strings
        str = @scanner.scan_until(/([^\\]|^)#{quote}/)
        if str.nil?
            raise Puppet::LexError.new("Unclosed quote after '%s' in '%s'" %
                [self.last,self.rest])
        else
            str.sub!(/#{quote}\Z/,"")
            str.gsub!(/\\#{quote}/,quote)
        end

        return str
    end

    # just parse a string, not a whole file
    def string=(string)
        @scanner = StringScanner.new(string)
    end
end
