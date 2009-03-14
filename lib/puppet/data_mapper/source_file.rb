class Puppet::DataMapper::SourceFile
    include DataMapper::Resource
    has_one :host
    has_one :resource

    property :id, Serial
    property :filename, String, :index => true
    property :path, String
    property :updated_at, DateTime
    property :created_at, DateTime
end
