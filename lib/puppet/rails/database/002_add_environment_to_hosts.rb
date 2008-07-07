class AddEnvironmentToHosts < ActiveRecord::Migration
  def self.up
    add_column :hosts, :environment, :string 
  end

  def self.down
    remove_column :hosts, :environment
  end
end
