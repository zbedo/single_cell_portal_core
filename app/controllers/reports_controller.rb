class ReportsController < ApplicationController

  before_filter do
    authenticate_user!
    authenticate_reporter
  end

  # show summary statistics about portal studies and users
  def index
    # only load studies not queued for deletion
    @all_studies = Study.where(queued_for_deletion: false).to_a
    @public_studies = @all_studies.select {|s| s.public}
    @private_studies = @all_studies.select {|s| !s.public}

    # set up local collections and labels
    users = User.all.to_a
    public_label = 'Public'
    private_label = 'Private'
    study_types = [public_label, private_label]
    all_studies_label = study_types.join(' & ')

    # study distributions
    today = Date.today
    @private_study_age_dist = {private_label => @private_studies.map {|s| (today - s.created_at.to_date).to_i / 7}}
    @private_dist_avg = @private_study_age_dist[private_label].reduce(:+) / @private_study_age_dist[private_label].size.to_f

    @collab_dist = {all_studies_label => @all_studies.map {|s| s.study_shares.size}}
    @collab_dist_avg = @collab_dist[all_studies_label].reduce(:+) / @collab_dist[all_studies_label].size.to_f
    @cell_dist = @all_studies.map(&:cell_count)
    max_cells = @cell_dist.max - @cell_dist.max % 1000
    @cell_count_bin_dist = {'Public' => {}, 'Private' => {}}
    # bin studies by cell counts into groups of 1000
    0.step(max_cells, 1000).each do |bin|
      bin_label = "#{bin}-#{bin + 1000}"
      @cell_count_bin_dist['Public'][bin_label] = @public_studies.select {|s| s.cell_count >= bin && s.cell_count < (bin + 1000)}.size
      @cell_count_bin_dist['Private'][bin_label] = @private_studies.select {|s| s.cell_count >= bin && s.cell_count < (bin + 1000)}.size
    end
    @cell_avg = @cell_dist.reduce(:+) / @cell_dist.size.to_f

    # user distributions
    @user_study_dist = {all_studies_label => users.map {|u| u.studies.size}}
    email_domains = users.map(&:email).map {|email| email.split('@').last}.uniq
    totals_by_domain = {}
    user_study_email_dist = {}
    study_types.each do |study_type|
      user_study_email_dist[study_type] = {}
      email_domains.sort.each do |domain|
        totals_by_domain[domain] ||= 0
        count = users.select {|u| u.email =~ /#{domain}/}.map {|u| u.studies.select {|s| study_type == public_label ? s.public? : !s.public?}.size}.reduce(:+)
        totals_by_domain[domain] += count
        user_study_email_dist[study_type][domain] = count
      end
    end
    @user_study_avg = @user_study_dist[all_studies_label].reduce(:+) / @user_study_dist[all_studies_label].size.to_f
    @email_domain_avg = totals_by_domain.values.reduce(:+) / totals_by_domain.values.size

    # sort domain breakdowns by totals to order plot
    sorted_domains = totals_by_domain.sort_by {|k,v| v}.reverse.map(&:first)
    @sorted_email_domain_dist = {}
    study_types.each do |study_type|
      @sorted_email_domain_dist[study_type] = {}
      sorted_domains.each do |domain|
        @sorted_email_domain_dist[study_type][domain] = user_study_email_dist[study_type][domain]
      end
    end
  end

end
