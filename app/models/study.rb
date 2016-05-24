class Study
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user

  has_many :study_files, dependent: :destroy
  has_many :single_cells, dependent: :destroy
  has_many :expression_scores, dependent: :destroy
  has_many :precomputed_scores, dependent: :destroy

  # scoping clusters to allow easy access to top- and sub-level clusters
  has_many :clusters do
    def parent_clusters
      where(cluster_type: 'parent').to_a.delete_if {|c| c.cluster_points.empty? }
    end

    def sub_cluster(name)
      where(parent_cluster: name).to_a.delete_if {|c| c.cluster_points.empty? }
    end
  end

  field :name, type: String
  field :url_safe_name, type: String
  field :description, type: String
  field :public, type: Boolean, default: true

  accepts_nested_attributes_for :study_files, allow_destroy: true

  validates_uniqueness_of :name

  before_save :set_url_safe_name
  after_save :check_public?

  def data_public_path
    Rails.root.join('public', 'single_cell_demo', 'data', self.url_safe_name)
  end

  def data_store_path
    Rails.root.join('data', self.url_safe_name)
  end

  def visibility
    self.public? ? "<span class='label label-success'>Public</span>".html_safe : "<span class='label label-danger'>Private</span>".html_safe
  end

  # method to parse master expression scores file for study and populate collection
  def make_expression_scores
    Rails.logger.level = 4
    @count = 0
    start_time = Time.now
    # open data file and grab header row with name of all cells, deleting 'GENE' at start
    expression_data = File.open(File.join(self.data_load_path, 'DATA_MATRIX_LOG_TPM.txt'))
    cells = expression_data.readline.chomp().split("\t")
    cells.shift
    # store study id for later to save memory
    study_id = self._id
    while !expression_data.eof?
      # grab single row of scores, parse out gene name at beginning
      row = expression_data.readline.chomp().split("\t")
      gene_name = row.shift
      # convert all remaining strings to floats, then store only significant values (!= 0)
      scores = row.map(&:to_f)
      significant_scores = {}
      scores.each_with_index do |score, index|
        unless score == 0.0
          significant_scores[cells[index]] = score
        end
      end
      # create expression score object
      ExpressionScore.create({gene: gene_name, searchable_gene: gene_name.downcase, scores: significant_scores, study_id: study_id})
      @count += 1
    end
    # clean up, print stats
    expression_data.close
    end_time = Time.now
    time = (end_time - start_time).divmod 60.0
    puts "Completed!"
    puts "ExpressionScores created: #{@count}"
    puts "Total Time: #{time.first} minutes, #{time.last} seconds"
  end

  # will load source data from expected public directory location and populate collections
  def parse_source_data
    data_path = self.data_public_path
    # turn off logging to make data load faster
    Rails.logger.level = 4

    if Dir.exists?(data_path)
      Dir.chdir(data_path)
      @cell_count = 0
      @cluster_count = 0
      @cluster_point_count = 0

      # load cluster assignments
      clusters_data = File.open('CLUSTER_AND_SUBCLUSTER_INDEX.txt').readlines.map(&:chomp).delete_if {|line| line.blank? }
      @all_clusters = {}
      clusters_data.shift
      clusters_data.each do |line|
        vals = line.split("\t")
        cluster_name = vals[1]
        sub_cluster_name = vals[2]
        cell_name = vals[0]
        @all_clusters[cell_name] = {cluster: cluster_name, sub_cluster: sub_cluster_name}

        # create cluster and single_cell objects now to associate later as some cells/clusters have no coordinate data
        parent_cluster = Cluster.where(name: cluster_name, cluster_type: 'parent').first
        sub_cluster = Cluster.where(name: sub_cluster_name, cluster_type: 'sub_cluster').first
        if parent_cluster.blank?
          parent_cluster = self.clusters.build(name: cluster_name, cluster_type: 'parent')
          parent_cluster.save
          @cluster_count += 1
        end
        if sub_cluster.blank?
          sub_cluster = self.clusters.build(name: sub_cluster_name, parent_cluster: cluster_name, cluster_type: 'sub_cluster')
          sub_cluster.save
          @cluster_count += 1
        end
        parent_cell = SingleCell.where(name: cell_name, study_id: self._id, cluster_id: parent_cluster._id).first
        sub_cell = SingleCell.where(name: cell_name, study_id: self._id, cluster_id: sub_cluster._id).first
        if parent_cell.blank?
          parent_cell = self.single_cells.build(name: cell_name, cluster_id: parent_cluster._id)
          parent_cell.save
          @cell_count += 1
        end
        if sub_cell.blank?
          sub_cell = self.single_cells.build(name: cell_name, cluster_id: sub_cluster._id)
          sub_cell.save
          @cell_count += 1
        end
      end

      # find all coordinates data
      coordinates_files = Dir.glob("Coordinates_*.txt")
      coordinates_files.each do |file|

        # get all lines and proper indices
        lines = File.open(file).readlines.map(&:chomp).delete_if {|line| line.blank? }
        headers = lines.shift.split("\t")
        cell_name_index = headers.index('CELL_NAME')
        x_index = headers.index('X')
        y_index = headers.index('Y')
        lines.each do |line|

          # parse each line and get values
          vals = line.split("\t")
          name = vals[cell_name_index]
          x = vals[x_index]
          y = vals[y_index]

          # load correct cluster & single_cell
          if file == 'Coordinates_Major_cell_types.txt'
            @cluster_name = @all_clusters[name][:cluster]
            @cluster_type = 'parent'
            @parent_cluster = nil
          else
            @cluster_name = @all_clusters[name][:sub_cluster]
            @cluster_type = 'sub_cluster'
            @parent_cluster = @all_clusters[name][:cluster]
          end

          cluster = Cluster.where(name: @cluster_name, cluster_type: @cluster_type).first
          cell = SingleCell.where(name: name, study_id: self._id, cluster_id: cluster._id).first

          unless cell.nil?
            # finally, create cluster point with association to cluster & single_cell
            cluster_point = cluster.cluster_points.build(x: x, y: y, single_cell_id: cell._id)
            cluster_point.save
            @cluster_point_count += 1
          end
        end
      end
      # log messages
      puts "Finished loading data for Study: #{self.name}:"
      puts "Single Cells created: #{@cell_count}"
      puts "Clusters created: #{@cluster_count}"
      puts "Cluster Points created: #{@cluster_point_count}"
      true
    else
      puts "Cannot open data directory for Study: #{self.name}."
      false
    end
  end

  # parse precomputed marker gene files and create documents to render in Morpheus
  def make_precomputed_scores
    data_path = self.data_public_path
    # turn off logging to make data load faster
    Rails.logger.level = 4
    @count = {}
    start_time = Time.now
    if Dir.exists?(data_path)
      Dir.chdir(data_path)
      marker_files = Dir.glob("*_marker_genes.txt")
      marker_files.each do |file|
        precomputed_score = self.precomputed_scores.build(name: file.gsub(/_/, ' ').chomp('.txt'))
        @count[file] = 0
        marker_data = File.open(file).readlines.map(&:chomp).delete_if {|line| line.blank? }
        clusters = marker_data.shift().split("\t")
        clusters.shift # remove 'Gene Name' at start
        precomputed_score.clusters = clusters
        rows = []
        marker_data.each do |line|
          vals = line.split("\t")
          gene = vals.shift
          row = {"#{gene}" => {}}
          clusters.each_with_index do |cluster, index|
            row[gene][cluster] = vals[index].to_f
          end
          rows << row
          @count[file] += 1
        end
        precomputed_score.gene_scores = rows
        precomputed_score.save
      end
    end
    end_time = Time.now
    time = (end_time - start_time).divmod 60.0
    puts "Completed!"
    puts "Total objects created"
    @count.each do |file, count|
      puts "#{file}: #{count}"
    end
    puts "Total Time: #{time.first} minutes, #{time.last} seconds"
    true
  end

  private

  # sets a url-safe version of study name (for linking)
  def set_url_safe_name
    self.url_safe_name = self.name.downcase.gsub(/[^a-zA-Z0-9]+/, '-').chomp('-')
  end

  # used for creating symbolic links to make data downloadable
  def check_public?
    if self.public?
      if !Dir.exists?(self.data_public_path)
        Dir.mkdir(self.data_public_path)
        FileUtils.ln_s(Dir.glob("#{self.data_store_path}/*"), self.data_public_path)
      end
    elsif !self.public?
      if Dir.exists?(self.data_public_path)
        FileUtils.remove_entry_secure(self.data_public_path, force: true)
      end
    end
  end
end
