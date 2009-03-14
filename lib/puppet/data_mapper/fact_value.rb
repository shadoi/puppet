class Puppet::DataMapper::FactValue
    include DataMapper::Resource
    belongs_to :fact_name
    belongs_to :host

    property :id, Serial
    property :value, Text, :nullable => false
    property :fact_name_id, Integer, :nullable => false, :index => true
    property :host_id, Integer, :nullable => false, :index => true
    property :updated_at, DateTime
    property :created_at, DateTime
end
