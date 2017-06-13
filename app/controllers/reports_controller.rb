class ReportsController < ApplicationController

  before_filter do
    authenticate_user!
    authenticate_reporter
  end

  def index
    @all_studies = Study.all.to_a
    @public_studies = @all_studies.select {|s| s.public}
    @private_studies = @all_studies.select {|s| !s.public}

    # study distributions
    today = Date.today
    @private_study_age_dist = {'Private' => @private_studies.map {|s| (today - s.created_at.to_date).to_i / 7}}
    @private_dist_avg = @private_study_age_dist['Private'].reduce(:+) / @private_study_age_dist['Private'].size.to_f

    @collab_dist = {'All' => @all_studies.map {|s| s.study_shares.size}}
    @collab_dist_avg = @collab_dist['All'].reduce(:+) / @collab_dist['All'].size.to_f


    @cell_dist = @all_studies.map(&:cell_count)
    max_cells = @cell_dist.max - @cell_dist.max % 1000
    @cell_count_bin_dist = {'Public' => {}, 'Private' => {}}
    0.step(max_cells, 1000).each do |bin|
      @cell_count_bin_dist['Public']["#{bin}-#{bin + 1000}"] = @public_studies.map(&:cell_count).select {|c| c >= bin && c < bin + 1000}.size
      @cell_count_bin_dist['Private']["#{bin}-#{bin + 1000}"] = @private_studies.map(&:cell_count).select {|c| c >= bin && c < bin + 1000}.size
    end
    @cell_avg = @cell_dist.reduce(:+) / @cell_dist.size.to_f

    # user distributions
    @users = User.all.to_a
    @user_study_dist = {"All" => @users.map {|u| u.studies.size}}
    @email_domains = @users.map(&:email).map {|email| email.split('@').last}.uniq
    @user_study_email_dist = {}
    ['Public', 'Private'].each do |study_type|
      @user_study_email_dist[study_type] = {}
      @email_domains.sort.each do |domain|
        @user_study_email_dist[study_type][domain] = @users.select {|u| u.email =~ /#{domain}/}.map {|u| u.studies.select {|s| study_type == 'Public' ? s.public? : !s.public?}.size}.reduce(:+)
      end
    end
    @user_study_avg = @user_study_dist['All'].reduce(:+) / @user_study_dist['All'].size.to_f
    @email_domain_avg = @user_study_email_dist.values.map {|v| v.values.reduce(:+)}.reduce(:+) / @user_study_email_dist.values.map(&:values).uniq.size.to_f

  end

end
