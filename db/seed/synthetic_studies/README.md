# Synthetic data readme

## This folder contains several synthetic studies, meant to allow testing and display of various portal features.

## To add a new study
1. Make a new folder in db/seed/synthetic_studies with a short name evocative of the study, or the type of cells
2. Create a study_info.json file (you can model it after `db/seed/synthetic_studies/cow_blood/study_info.json`) specifying
     * name
     * description
     * data_dir (set to 'test')
3. Add any study-associated files (e.g. a metadata.tsv) file to the directory, and update the "files" list in your study_info.json to point to them.  You will need to specify at least 'type' and 'filename' for each file.  Note that 'Metadata' is the only type currenty confirmed to work in the synthetic ingest populator
4. To test your study, open a rails console (either `rails c` in your terminal if you're running non-Dockerized, or `bundle exec rails c` inside the running container if you're running Dockerized) and run `SyntheticStudyPopulator.populate('<<study_folder>>')`.  You do not need to specify the full path.  So e.g. to populate the synthtetic study in db/seed/synthetic_studies/cow_blood, run `SyntheticStudyPopulator.populate('cow_blood')`
