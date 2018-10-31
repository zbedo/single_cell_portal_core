class UpdateRegisteredTaxons < Mongoid::Migration
  # this migration is a duplicate of 20181004151831_auto_populate_species_info because the contents of
  # default_species_assemblies.txt has changed
  def self.up
    admin_user = User.where(admin: true).first
    path = Rails.root.join('lib', 'assets', 'default_species_assemblies.txt')
    if File.exists?(path) && admin_user.present?
      Taxon.parse_from_file(path, admin_user)
    end
  end

  def self.down
    Taxon.destroy_all
  end
end