# Created on 2008-01-19
# Copyright Luke Kanies

# A common module to handle tagging.
module Puppet::Util::Tagging
    # Add a tag to our current list.  These tags will be added to all
    # of the objects contained in this scope.
    def tag(*ary)
        @tags ||= []

        qualified = []

        ary.collect { |tag| tag.to_s.downcase }.each do |tag|
            fail(Puppet::ParseError, "Invalid tag %s" % tag.inspect) unless valid_tag?(tag)
            qualified << tag if tag.include?("::")
            @tags << tag unless @tags.include?(tag)
        end

        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        qualified.collect { |name| x = name.split("::") }.flatten.each { |tag| @tags << tag unless @tags.include?(tag) }
    end

    # Are we tagged with the provided tag?
    def tagged?(tag)
        defined?(@tags) and @tags.include?(tag.to_s)
    end

    # Return a copy of the tag list, so someone can't ask for our tags
    # and then modify them.
    def tags
        @tags ||= []
        @tags.dup
    end

    private

    def valid_tag?(tag)
        tag =~ /^\w[-\w:.]*$/
    end
end
