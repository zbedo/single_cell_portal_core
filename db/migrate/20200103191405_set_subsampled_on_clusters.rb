class SetSubsampledOnClusters < Mongoid::Migration
  def self.up
    ClusterGroup.all.each do |cluster|
      if cluster.points > 1000
        cluster.update(subsampled: true)
      end
    end
  end

  def self.down
    ClusterGroup.all.each do |cluster|
      cluster.remove_attribute(:subsampled)
    end
  end
end