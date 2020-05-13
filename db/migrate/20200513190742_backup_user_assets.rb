class BackupUserAssets < Mongoid::Migration
  def self.up
    UserAssetService.push_assets_to_remote
  end

  def self.down
    bucket = UserAssetService.get_storage_bucket
    bucket.delete
  end
end
