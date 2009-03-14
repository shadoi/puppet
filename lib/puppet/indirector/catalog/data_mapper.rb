require 'puppet/node/catalog'
require 'puppet/indirector/data_mapper'

class Puppet::Node::Catalog::DataMapper < Puppet::Indirector::DataMapper
    desc "Store catalogs to a database using DataMapper."

    # I'm not sure if we even need this.. or if the main terminus code should be here.
end
