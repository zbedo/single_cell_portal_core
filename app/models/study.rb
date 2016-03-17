class Study
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :study_files
  has_many :single_cells
  has_many :expression_scores

  # scoping clusters to allow easy access to top- and sub-level clusters
  has_many :clusters do
    def parent_clusters
      where(cluster_type: 'parent').to_a
    end

    def sub_cluster(name)
      where(parent_cluster: name).to_a
    end
  end

  field :name, type: String
  field :url_safe_name, type: String
  field :description, type: String
  field :public, type: Boolean, default: true

  before_save :set_url_safe_name

  def data_load_path
    Rails.root.join('public', 'data', self.url_safe_name)
  end

  # load all study files into database for downloading
  def create_study_files
    data_path = self.data_load_path
    if Dir.exists?(data_path)
      Dir.chdir(data_path)
      entries = Dir.glob('*')
      entries.each do |file|
        study_file = self.study_files.build(name: file, description: 'Default description', path: "#{data_path}/#{file}")
        study_file.save!
        puts "Created study file: #{study_file.name}"
      end
      true
    else
      puts "Cannot open data directory for Study: #{self.name}."
      false
    end
  end

  # method to parse expression matrix into individual scores
  def parse_expression_sparse_matrix
    Rails.logger.level = 4
    @score_count = 0
    @missing = []
    time = Benchmark.realtime {
      # load all rows
      expression_data = File.open(File.join(self.data_load_path, '/DATA_MATRIX_LOG_TPM.txt')).readlines
      total_rows = expression_data.size
      # grab list of cells, then shift out 'GENE' label at start
      cells = expression_data.shift.split("\t")
      cells.shift
      # parse each row, saving only non-zero scores
      expression_data.each_with_index do |row, row_index|
        scores = row.chomp().split("\t")
        # grab gene name from first value
        gene_name = scores.shift
        puts "Processing row #{row_index}:#{gene_name} of #{total_rows}"
        # iterate each score, saving only informative scores
        scores.each_with_index do |score, index|
          unless score.to_f == 0.0
            cell = SingleCell.where(name: cells[index]).first
            @score_count += 1
            #puts "Would have stored ExpressionScore: cell_name: #{cells[index]}, gene: #{gene_name}, value: #{score}"
            if cell.nil?
              @missing.index(cells[index]).nil? ? @missing << cells[index] : nil
              #puts "Cell #{cells[index]} does not exist yet"
            end
          end
        end
      end
    }
    puts "Completed!"
    puts "Scores recorded: #{@score_count}"
    puts "Missing cells: #{@missing.size}"
    puts "Total time: #{time}"
  end

  # method to parse master expression scores file for study and populate collection
  def make_expression_scores
    Rails.logger.level = 4
    @count = 0
    start_time = Time.now
    expression_data = File.open(File.join(self.data_load_path, 'DATA_MATRIX_LOG_TPM.txt'))
    cells = expression_data.readline.chomp().split("\t")
    cells.shift
    while !expression_data.eof?
      row = expression_data.readline.chomp().split("\t")
      gene_name = row.shift
      scores = row.map(&:to_f)
      significant_scores = Hash[cells.zip(scores)].reject {|k,v| v == 0.0}
      expression_score = self.expression_scores.build(gene: gene_name, scores: significant_scores)
      expression_score.save!
      @count += 1
    end
    expression_data.close
    end_time = Time.now
    time = (end_time - start_time).divmod 60.0
    puts "Completed!"
    puts "ExpressionScores created: #{@count}"
    puts "Total Time: #{time.first} minutes, #{time.last} seconds"
  end

  # will load source data from expected public directory location and populate collections
  def parse_source_data
    data_path = self.data_load_path
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
        @all_clusters[vals[0]] = {cluster: vals[1], sub_cluster: vals[2]}
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

          # create cluster first, determining type and saving correct name
          if file == 'Coordinates_Major_cell_types.txt'
            @cluster_name = @all_clusters[vals[cell_name_index]][:cluster]
            @cluster_type = 'parent'
            @parent_cluster = nil
          else
            @cluster_name = @all_clusters[vals[cell_name_index]][:sub_cluster]
            @cluster_type = 'sub_cluster'
            @parent_cluster = @all_clusters[vals[cell_name_index]][:cluster]
          end
          if !Cluster.where(name: @cluster_name, cluster_type: @cluster_type).exists?
            if @parent_cluster.nil?
              @cluster = self.clusters.build(name: @cluster_name, cluster_type: @cluster_type)
            else
              @cluster = self.clusters.build(name: @cluster_name, cluster_type: @cluster_type, parent_cluster: @parent_cluster)
            end
            @cluster.save!
            @cluster_count += 1
          else
            @cluster = Cluster.where(name: @cluster_name, cluster_type: @cluster_type).first
          end

          # create or find single_cell and map associations to study and cluster
          if !SingleCell.where(name: name, study_id: self._id).any?
            @cell = self.single_cells.build(name: name, cluster_id: @cluster._id)
            @cell.save!
            @cell_count += 1
          else
            @cell = SingleCell.where(name: name, study_id: self._id).first
          end

          # finally, create cluster point with association to cluster & single_cell
          @cluster_point = @cluster.cluster_points.build(x: x, y: y, single_cell_id: @cell._id)
          @cluster_point.save!
          @cluster_point_count += 1
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

  private

  # sets a url-safe version of study name (for linking)
  def set_url_safe_name
    self.url_safe_name = self.name.downcase.gsub(/[^a-zA-Z0-9]+/, '-').chomp('-')
  end
end
