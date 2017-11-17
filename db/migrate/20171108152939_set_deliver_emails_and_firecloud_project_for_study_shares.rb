# set default firecloud project for all study shares and deliver_emails flag
class SetDeliverEmailsAndFirecloudProjectForStudyShares < Mongoid::Migration
  def self.up
    StudyShare.all.each do |share|
      project = share.study.firecloud_project
      share.update!(firecloud_project: project, deliver_emails: true)
    end
  end

  def self.down
    StudyShare.all.unset(:deliver_emails)
    StudyShare.all.unset(:firecloud_project)
  end
end