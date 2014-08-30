require 'puppet/provider/parsedfile'

known = nil
case Facter.value(:operatingsystem)
when "Darwin": known = "/etc/ssh_known_hosts"
else
    known = "/etc/ssh/ssh_known_hosts"
end

Puppet::Type.type(:sshkey).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => known,
    :filetype => :flat
) do
    desc "Parse and generate host-wide known hosts files for SSH."

    text_line :comment, :match => /^#/
    text_line :blank, :match => /^\s+/

    record_line :parsed, :fields => %w{name type key},
        :post_parse => proc { |hash|
            if hash[:name] =~ /,/
                names = hash[:name].split(",")
                hash[:name] = names.shift
                hash[:alias] = names
            end
        },
        :pre_gen => proc { |hash|
            if hash[:alias]
                names = [hash[:name], hash[:alias]].flatten

                hash[:name] = [hash[:name], hash[:alias]].flatten.join(",")
                hash.delete(:alias)
            end
        }
end

