class ReportsController < ApplicationController

  ###
  #
  # This controller only displays charts with information about site usage (e.g. number of studies, users, etc.)
  #
  ###

  before_action do
    authenticate_user!
    authenticate_reporter
  end

  # show summary statistics about portal studies and users
  def index
    # only load studies not queued for deletion
    @all_studies = Study.where(queued_for_deletion: false).to_a
    @public_studies = @all_studies.select {|s| s.public}
    @private_studies = @all_studies.select {|s| !s.public}
    now = Time.now
    one_week_ago = now - 1.weeks

    # set up local collections and labels
    users = User.all.to_a
    public_label = 'Public'
    private_label = 'Private'
    study_types = [public_label, private_label]
    all_studies_label = study_types.join(' & ')

    # study distributions
    today = Date.today
    @private_study_age_dist = {private_label => @private_studies.map {|s| (today - s.created_at.to_date).to_i / 7}}
    if @private_study_age_dist[private_label].empty?
      @private_dist_avg = 0
    else
      @private_dist_avg = @private_study_age_dist[private_label].reduce(0, :+) / @private_study_age_dist[private_label].size.to_f
    end

    @collab_dist = {all_studies_label => @all_studies.map {|s| s.study_shares.size}}
    @collab_dist_avg = @collab_dist[all_studies_label].reduce(0, :+) / @collab_dist[all_studies_label].size.to_f
    @cell_dist = @all_studies.map(&:cell_count)
    # calculate bin size as 10 ** two orders of magnitude less than max cells
    bin_size = 10 ** (@cell_dist.max.to_s.size - 2)
    max_cells = @cell_dist.max - @cell_dist.max % bin_size
    @cell_count_bin_dist = {public_label => {}, private_label => {}}
    0.step(max_cells, bin_size).each do |bin|
      bin_label = "#{bin}-#{bin + bin_size}"
      @cell_count_bin_dist[public_label][bin_label] = @public_studies.select {|s| s.cell_count >= bin && s.cell_count < (bin + bin_size)}.size
      @cell_count_bin_dist[private_label][bin_label] = @private_studies.select {|s| s.cell_count >= bin && s.cell_count < (bin + bin_size)}.size
    end
    @cell_avg = @cell_dist.reduce(0, :+) / @cell_dist.size.to_f

    # cells over time
    @cells_over_time = { 'All Studies' => {}, public_label => {}, private_label => {}}
    @all_studies.each do |study|
      # get date as YYYY-MM
      date = study.created_at.strftime("%Y-%m")
      cell_count = study.cell_count
      # initialize entry for that date in cumulative count
      @cells_over_time['All Studies'][date] ||= 0
      @cells_over_time['All Studies'][date] += cell_count
      # determine which bucket to add cell count into (Public/Private)
      label = study.public? ? public_label : private_label
      @cells_over_time[label][date] ||= 0
      @cells_over_time[label][date] += cell_count
      # create an empty entry at the same timepoint in the opposite bucket so we have the same number of timepoints in both
      opposite_label = label == public_label ? private_label : public_label
      @cells_over_time[opposite_label][date] ||= 0
    end
    # calculate cumulative rollups
    @cells_over_time.each do |visibility, totals|
      sum = 0
      totals.sort_by {|date, count| date}.each_with_index do |entry, index|
        if index == 0
          sum = entry.last
        else
          sum += entry.last
          @cells_over_time[visibility][entry.first] = sum
        end
      end
    end

    # user distributions
    @user_study_dist = {all_studies_label => users.map {|u| u.studies.size}}
    email_domains = users.map(&:email).map {|email| email.split('@').last}.uniq
    totals_by_domain = {}
    user_study_email_dist = {}
    study_types.each do |study_type|
      user_study_email_dist[study_type] = {}
      email_domains.sort.each do |domain|
        totals_by_domain[domain] ||= 0
        count = users.select {|u| u.email =~ /#{domain}/}.map {|u| u.studies.select {|s| study_type == public_label ? s.public? : !s.public?}.size}.reduce(0, :+)
        totals_by_domain[domain] += count
        user_study_email_dist[study_type][domain] = count
      end
    end
    @user_study_avg = @user_study_dist[all_studies_label].reduce(0, :+) / @user_study_dist[all_studies_label].size.to_f
    @email_domain_avg = totals_by_domain.values.reduce(0, :+) / totals_by_domain.values.size

    # compute time-based breakdown of returning user counts
    @returning_users_by_week = {}
    user_timepoints = ReportTimePoint.where(name: 'Weekly Returning Users', :date.lte => today).order(date: :desc).take(26)
    user_timepoints.each do |timepoint|
      @returning_users_by_week[timepoint.date.to_s] = timepoint.value[:count]
    end
    # now figure out returning users since last report
    if user_timepoints.any?
      latest_date = user_timepoints.sort_by {|tp| tp.date}.last.date
      if latest_date < today
        next_period = latest_date + 1.week
        @returning_users_by_week[next_period.to_s] = users.select {|user| user.last_sign_in_at >= latest_date || user.current_sign_in_at >= latest_date }.size
      end
    else
      latest_date = today - 1.week
      @returning_users_by_week[today.to_s] = users.select {|user| user.last_sign_in_at >= latest_date || user.current_sign_in_at >= latest_date }.size
    end

    # sort domain breakdowns by totals to order plot
    sorted_domains = totals_by_domain.sort_by {|k,v| v}.reverse.map(&:first)
    @sorted_email_domain_dist = {}
    study_types.each do |study_type|
      @sorted_email_domain_dist[study_type] = {}
      sorted_domains.each do |domain|
        @sorted_email_domain_dist[study_type][domain] = user_study_email_dist[study_type][domain]
      end
    end

    # get pipeline statistics
    @pipeline_submissions = {}
    @pipeline_runtimes = {}
    @has_pipeline_stats = false
    # Deferring until Q2 2019; investigating better ways of calculating runtimes and costs
    #
    # AnalysisMetadatum.all.each do |analysis|
    #   @has_pipeline_stats = true
    #   study = analysis.study
    #   comp_method = analysis.payload['computational_method']
    #   parts = comp_method.split('/')
    #   pipeline_name = parts[parts.size - 2]
    #   # get runtime info
    #   tasks = analysis.payload['tasks']
    #   start_times = []
    #   stop_times = []
    #   tasks.each do |task|
    #     start_times << Time.parse(task['start_time'])
    #     stop_times << Time.parse(task['stop_time'])
    #   end
    #   if start_times.any? && stop_times.any?
    #     pipeline_start = start_times.sort.first
    #     pipeline_end = stop_times.sort.last
    #     runtime_in_min = (pipeline_end - pipeline_start) / 60.0
    #     input_size = 0
    #     @inputs = []
    #     # determine how many input files there were
    #     case pipeline_name
    #       when /cell-ranger/
    #         pipeline_inputs = analysis.payload['inputs'].detect {|input| input['name'] == 'cellranger.fastqs'}
    #         @inputs = pipeline_inputs['value']
    #       when /infercnv/
    #         pipeline_inputs = analysis.payload['inputs'].detect {|input| input['name'] == 'infercnv.expression_file'}
    #         @inputs = [pipeline_inputs['value']]
    #       else
    #         # make a guess, we have no idea
    #         pipeline_inputs = analysis.payload['inputs'].select {|input| input['name'] =~ /fastq/}
    #         pipeline_inputs.each do |input|
    #           @inputs << input['value']
    #         end
    #         @inputs.flatten!
    #     end
    #     input_files = @inputs.map {|input| input.gsub(/gs:\/\/#{study.bucket_id}\//, '')}
    #     # we need to now find the size of the files for the plot
    #     input_files.each do |file|
    #       case pipeline_name
    #         when /infercnv/
    #           study_file = study.study_files.by_type('Expression Matrix').detect {|f| f.name == file}
    #           if study_file.present? && !study_file.human_data?
    #             input_size += study_file.upload_file_size
    #           end
    #         else
    #           directory = file.include?('/') ? file.split('/').first : '/'
    #           study_directory = study.directory_listings.find_by(name: directory)
    #           if study_directory.present?
    #             study_directory_file = study_directory.files.detect {|f| f['name'] == file}
    #             input_size += study_directory_file['size']
    #           else
    #             study_file = study.study_files.by_type('Fastq').detect {|f| f.name == file}
    #             if study_file.present? && !study_file.human_data?
    #               input_size += study_file.upload_file_size
    #             end
    #           end
    #       end
    #     end
    #     if @pipeline_runtimes[pipeline_name].present?
    #       @pipeline_runtimes[pipeline_name][:inputs] << input_size
    #       @pipeline_runtimes[pipeline_name][:runtime] << runtime_in_min
    #     else
    #       @pipeline_runtimes[pipeline_name] = {inputs: [input_size], runtime: [runtime_in_min]}
    #     end
    #   end
    #   # add run to count totals for this pipeline
    #   date_bracket = analysis.created_at.strftime('%Y-%m')
    #   if @pipeline_submissions[pipeline_name].present?
    #     if @pipeline_submissions[pipeline_name][date_bracket].present?
    #       @pipeline_submissions[pipeline_name][date_bracket] += 1
    #     else
    #       @pipeline_submissions[pipeline_name][date_bracket] = 1
    #     end
    #   else
    #     @pipeline_submissions[pipeline_name] = {"#{date_bracket}" => 1}
    #   end
    # end
  end

  def report_request

  end

  # send a message to the site administrator requesting a new report plot
  def submit_report_request
    @subject = report_request_params[:subject]
    @requester = report_request_params[:requester]
    @message = report_request_params[:message]

    SingleCellMailer.admin_notification(@subject, @requestor, @message).deliver_now
    redirect_to reports_path, notice: 'Your request has been submitted.' and return
  end

  private

  def report_request_params
    params.require(:report_request).permit(:subject, :requester, :message)
  end
end
