class Puppet::DataMapper::ParamValue
    belongs_to :param_name
    belongs_to :resource

    property :id, Serial
    property :value, Text, :nullable => false
    property :param_name_id, Integer, :nullable => false, :index => true
    property :line, Integer
    property :resource_id, Integer, :index => true
    property :updated_at, DateTime
    property :created_at, DateTime

    def value
        val = self[:value]
        if val =~ /^--- \!/
            YAML.load(val)
        else
            val
        end
    end

    # I could not find a cleaner way to handle making sure that resource references
    # were consistently serialized and deserialized.
    def value=(val)
        if val.is_a?(Puppet::Parser::Resource::Reference)
            self[:value] = YAML.dump(val)
        else
            self[:value] = val
        end
    end

end

