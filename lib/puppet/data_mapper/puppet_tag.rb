require 'puppet/data_mapper/resource_tag'
class Puppet::DataMapper::PuppetTag
    include DataMapper::Resource
    has n, :resource_tags
    has n, :resources, :through => :resource_tags

    property :id, Serial
    property :name, String
    property :updated_at, DateTime
    property :created_at, DateTime
end
