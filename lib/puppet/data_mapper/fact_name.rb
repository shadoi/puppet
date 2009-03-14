require 'puppet/data_mapper/fact_value'

class Puppet::DataMapper::FactName
    include DataMapper::Resource
    has n, :fact_values

    property :id, Serial
    property :name, String, :nullable => false, :index => true
    property :updated_at, DateTime
    property :created_at, DateTime
end
