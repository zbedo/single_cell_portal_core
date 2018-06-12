class SetReadOnlyAccessOnStudies < Mongoid::Migration
  def self.up
    Study.all.each do |study|
      study.set_readonly_access
    end
  end

  def self.down
    Study.all.each do |study|
      access_level = 'NO ACCESS'
      readonly_acl = Study.firecloud_client.create_workspace_acl(Study.read_only_firecloud_client.issuer, access_level, false, false)
      Study.firecloud_client.update_workspace_acl(study.firecloud_project, study.firecloud_workspace, readonly_acl)
    end
  end
end