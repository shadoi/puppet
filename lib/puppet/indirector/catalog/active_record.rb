require 'puppet/node/catalog'
require 'puppet/indirector/active_record'

class Puppet::Node::Catalog::ActiveRecord < Puppet::Indirector::ActiveRecord
    desc "Store catalogs to a database using ActiveRecord."

    # I'm not sure if we even need this.. or if the main terminus code should be here.
end
