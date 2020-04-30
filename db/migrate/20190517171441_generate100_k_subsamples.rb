class Generate100KSubsamples < Mongoid::Migration
  def self.up
    ClusterGroup.all.each do |cluster|
      if cluster.points > 100000
        cell_metadata = CellMetadatum.where(study_id: cluster.study.id)
        # create cluster-based annotation subsamples first
        if cluster.cell_annotations.any?
          cluster.cell_annotations.each do |cell_annot|
            cluster.delay.generate_subsample_arrays(100000, cell_annot[:name], cell_annot[:type], 'cluster')
          end
        end
        # create study-based annotation subsamples
        cell_metadata.each do |metadata|
          cluster.delay.generate_subsample_arrays(100000, metadata.name, metadata.annotation_type, 'study')
        end
        CacheRemovalJob.new(cluster.study.accession).delay(queue: :cache).perform
      end
    end
  end

  def self.down
    ClusterGroup.all.each do |cluster|
      if cluster.points > 100000
        DataArray.where(study_id: cluster.study.id, study_file_id: cluster.study_file.id, linear_data_id: cluster.id,
                        linear_data_type: 'ClusterGroup', subsample_threshold: 100000).delete_all
        CacheRemovalJob.new(cluster.study.accession).delay(queue: :cache).perform
      end
    end
  end
end
