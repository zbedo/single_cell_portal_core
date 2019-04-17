class BackfillAnalysisSubmissions < Mongoid::Migration
  def self.up
    AnalysisMetadatum.all.each do |analysis|
      study = analysis.study
      puts "Creating Analysis Submission for #{study.firecloud_project}/#{study.firecloud_workspace}:#{analysis.submission_id}"
      AnalysisSubmission.initialize_from_submission(study, analysis.submission_id)
      puts "Analysis Submission for #{study.firecloud_project}/#{study.firecloud_workspace}:#{analysis.submission_id} created"
    end
  end

  def self.down
    AnalysisSubmission.delete_all
  end
end