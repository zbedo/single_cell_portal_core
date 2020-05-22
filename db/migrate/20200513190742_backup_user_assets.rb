class BackupUserAssets < Mongoid::Migration
  def self.up
    UserAssetService.push_assets_to_remote
  end

  def self.down
  end
end
