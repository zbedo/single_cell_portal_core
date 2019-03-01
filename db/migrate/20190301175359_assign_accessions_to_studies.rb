class AssignAccessionsToStudies < Mongoid::Migration
  def self.up
    StudyAccession.assign_accessions
  end

  def self.down
    Study.update_all(accession: nil)
    StudyAccession.destroy_all
  end
end