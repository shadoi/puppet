require 'puppet/util/rails/collection_merger'
require 'puppet/data_mapper/param_value'

class Puppet::DataMapper::ParamName
    include DataMapper::Resource
    include Puppet::Util::CollectionMerger
    has n, :param_values

    property :id, Serial
    property :name, String, :nullable => false, :index => true
    property :updated_at, DateTime
    property :created_at, DateTime

    def to_resourceparam(resource, source)
        hash = {}
        hash[:name] = self.name.to_sym
        hash[:source] = source
        hash[:value] = resource.param_values.find(:all, :conditions => [ "param_name_id = ?", self.id]).collect { |v| v.value }
        if hash[:value].length == 1
            hash[:value] = hash[:value].shift
        elsif hash[:value].empty?
            hash[:value] = nil
        end
        Puppet::Parser::Resource::Param.new hash
    end
end

