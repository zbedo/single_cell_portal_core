class CacheRemovalJob < Struct.new(:cache_key)

  ###
  #
  # CacheRemovalJob: class to delete matching cache files in the background to avoid tying up processes/resources in the foreground
  #
  ###

  def perform
    Rails.logger.info "#{Time.zone.now}: Deleting caches for #{cache_key}"
    Rails.cache.delete_matched(/#{cache_key}/)
    Rails.logger.info "#{Time.zone.now}: caches successfully cleared"
  end
end
