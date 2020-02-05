
# class to populate mock studies from files.
# See db/seed/mock_studies for exampels of the file formats
class MockStudyPopulator
  DEFAULT_MOCK_STUDY_PATH = Rails.root.join('db', 'seed', 'mock_studies')
  # populates all studies defined in db/seed/mock_studies
  def self.populate_all(user: User.first)
    study_names = Dir.glob(DEFAULT_MOCK_STUDY_PATH.join('*')).select {|f| File.directory? f}
    study_names.each do |study_name|
      populate(study_name, user: user)
    end
  end

  # populates the mock study specified in the given folder (e.g. ./db/seed/mock_studies/blood)
  # destroys any existing studies and workspace data corresponding to that study
  def self.populate(mock_study_folder, user: User.first)
    if (mock_study_folder.exclude?('/'))
      mock_study_folder = DEFAULT_MOCK_STUDY_PATH.join(mock_study_folder).to_s
    end
    study_info_file = File.read(mock_study_folder + '/study_info.json')
    study_config = JSON.parse(study_info_file)

    puts("Populating mock study from #{mock_study_folder}")
    study = create_study(mock_study_folder, study_config, user)
    add_files(study, study_config, mock_study_folder, user)
  end

  private

  def self.create_study(mock_study_folder, study_config, user)
    existing_study = Study.find_by(name: study_config['study']['name'])
    if existing_study
      puts("Destroying Study #{existing_study.name}, id #{existing_study.id}")
      existing_study.destroy_and_remove_workspace
    end

    study = Study.new(study_config['study'])
    study.user ||= user
    study.firecloud_project ||= ENV['PORTAL_NAMESPACE']
    puts("Saving Study #{study.name}")
    study.save!
    study
  end

  def self.add_files(study, study_config, mock_study_folder, user)
    file_infos = study_config['files']
    file_infos.each do |finfo|
      infile = File.open("#{mock_study_folder}/#{finfo['filename']}")
      study_file = StudyFile.create!(file_type: finfo['type'],
                        name: finfo['name'] ? finfo['name'] : finfo['filename'],
                        upload: infile,
                        use_metadata_convention: finfo['use_metadata_convention'] ? true : false,
                        status: 'uploading',
                        study: study)
      FileParseService.run_parse_job(study_file, study, user)
    end
  end
end
