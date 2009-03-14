class Puppet::DataMapper::ResourceTag
    include DataMapper::Resource
    belongs_to :puppet_tag
    belongs_to :resource

    property :id, Serial
    property :resource_id, Integer, :index => true
    property :puppet_tag_id, Integer, :index => true
    property :updated_at, DateTime
    property :created_at, DateTime
end
