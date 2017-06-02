class StudiesController < ApplicationController
  before_action :set_study, except: [:index, :new, :create, :download_private_file, :download_private_fastq_file]
  before_action :set_file_types, only: [:sync_study, :sync_study_file, :sync_orphaned_study_file, :update_study_file_from_sync]
  before_filter :check_edit_permissions, except: [:index, :new, :create, :download_private_file, :download_private_fastq_file]
  before_filter do
    authenticate_user!
    check_access_settings
  end
  # special before_filter to make sure FireCloud is available and pre-empt any calls when down
  before_filter :check_firecloud_status, except: [:index, :do_upload, :resume_upload, :update_status, :retrieve_wizard_upload, :parse ]

  # GET /studies
  # GET /studies.json
  def index
    @studies = Study.editable(current_user).to_a
  end

  # GET /studies/1
  # GET /studies/1.json
  def show
    @study_fastq_files = @study.study_files.by_type('Fastq')
    @directories = @study.directory_listings.are_synced
    # load study default options
    set_study_default_options
  end

  # GET /studies/new
  def new
    @study = Study.new
  end

  # GET /studies/1/edit
  def edit
  end

  # POST /studies
  # POST /studies.json
  def create
    @study = Study.new(study_params)

    respond_to do |format|
      if @study.save
        path = @study.use_existing_workspace ? sync_study_path(@study) : initialize_study_path(@study)
        format.html { redirect_to path, notice: "Your study '#{@study.name}' was successfully created." }
        format.json { render :show, status: :ok, location: @study }
      else
        format.html { render :new }
        format.json { render json: @study.errors, status: :unprocessable_entity }
      end
    end
  end

  # wizard for adding study files after user creates a study
  def initialize_study
    # load any existing files if user restarted for some reason (unlikely)
    initialize_wizard_files
    # check if study has been properly initialized yet, set to true if not
    if !@cluster_ordinations.last.new_record? && !@expression_file.new_record? && !@metadata_file.new_record? && !@study.initialized?
      @study.update_attributes(initialized: true)
    end
  end

  # allow a user to sync files uploaded outside the portal into a workspace bucket with an existing study
  def sync_study
    @study_files = @study.study_files
    @directories = @study.directory_listings.to_a
    # keep a list of what we expect to be
    @files_by_dir = {}
    @synced_study_files = []
    @synced_directories = []
    @unsynced_files = []
    @unsynced_directories = @study.directory_listings.unsynced
    @permissions_changed = []

    # first sync permissions if necessary
    begin
      portal_permissions = @study.local_acl
      firecloud_permissions = Study.firecloud_client.get_workspace_acl(@study.firecloud_workspace)
      firecloud_permissions['acl'].each do |user, permissions|
        # skip project owner permissions, they aren't relevant in this context
        if permissions['accessLevel'] == 'PROJECT_OWNER'
          next
        else
          # determine whether permissions are incorrect or missing completely
          if !portal_permissions.has_key?(user)
            new_share = @study.study_shares.build(email: user,
                                                 permission: StudyShare::PORTAL_ACL_MAP[permissions['accessLevel']],
                                                 firecloud_workspace: @study.firecloud_workspace
            )
            # skip validation as we don't wont to set the acl in FireCloud as it already exists
            new_share.save(validate: false)
            @permissions_changed << new_share
          elsif portal_permissions[user] != StudyShare::PORTAL_ACL_MAP[permissions['accessLevel']]
            # share exists, but permissions are wrong
            share = @study.study_shares.detect(email: user)
            share.update(permission: StudyShare::PORTAL_ACL_MAP[permissions['accessLevel']])
            @permissions_changed << share
          else
            # permissions are correct, skip
            next
          end
        end
      end
    rescue => e
      logger.error "#{Time.now}: error syncing ACLs in workspace bucket #{@study.firecloud_workspace} due to error: #{e.message}"
      redirect_to studies_path, alert: "We were unable to sync with your workspace bucket due to an error: #{e.message}" and return
    end

    # begin determining sync status with study_files and fastq data
    begin
      workspace_files = Study.firecloud_client.execute_gcloud_method(:get_workspace_files, @study.firecloud_workspace)
      # see process_workspace_bucket_files in private methods for more details on syncing
      process_workspace_bucket_files(workspace_files)
      while workspace_files.next?
        workspace_files = workspace_files.next
        process_workspace_bucket_files(workspace_files)
      end
    rescue RuntimeError => e
      logger.error "#{Time.now}: error syncing files in workspace bucket #{@study.firecloud_workspace} due to error: #{e.message}"
      redirect_to studies_path, alert: "We were unable to sync with your workspace bucket due to an error: #{e.message}" and return
    end

    # check against latest list of files by directory vs. what was just found to see if we are missing anything and add directory to unsynced list
    @directories.each do |directory|
      synced = true
      directory.files.each do |file|
        unless @files_by_dir[directory.name].find {|f| f[:name] = file[:name] && f[:size] == file[:size]}.nil?
          next
        else
          synced = false
          directory.files.delete(file)
        end
      end
      # if no longer synced, check if already in the list and remove as files list has changed
      if !synced
        @unsynced_directories.delete_if {|dir| dir.name == directory.name}
        @unsynced_directories << directory
      elsif directory.sync_status
        @synced_directories << directory
      end
    end

    # provisionally save unsynced directories so we don't have to pass huge arrays of filenames/sizes in the form
    # users clicking "don't sync" actually delete entries
    @unsynced_directories.each do |directory|
      directory.save
    end

    # now determine if we have study_files that have been 'orphaned' (cannot find a corresponding bucket file)
    @orphaned_study_files = @study_files - @synced_study_files
    @available_files = @unsynced_files.map {|f| {name: f.name, generation: f.generation, size: f.upload_file_size}}
  end

  # PATCH/PUT /studies/1
  # PATCH/PUT /studies/1.json
  def update
    # check if any changes were made to sharing for notifications
    if !study_params[:study_shares_attributes].nil?
      @share_changes = @study.study_shares.count != study_params[:study_shares_attributes].keys.size
      study_params[:study_shares_attributes].values.each do |share|
        if share["_destroy"] == "1"
          @share_changes = true
        end
      end
    else
      @share_changes = false
    end

    respond_to do |format|
      if @study.update(study_params)
        changes = @study.previous_changes.delete_if {|k,v| k == 'updated_at'}.keys.map {|k| k.humanize.capitalize}
        if @share_changes == true
          changes << 'Study shares'
        end
        if @study.study_shares.any?
          SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
        end
        format.html { redirect_to studies_path, notice: "Study '#{@study.name}' was successfully updated." }
        format.json { render :show, status: :ok, location: @study }
      else
        format.html { render :edit }
        format.json { render json: @study.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /studies/1
  # DELETE /studies/1.json
  def destroy
    # check if user is allowed to delete study
    if @study.can_delete?(current_user)
      name = @study.name
      ### DESTROY PROCESS FOR PORTAL
      #
      # Studies are not deleted on-demand due to memory performance.  Instead, studies are queued for deletion and
      # destroyed nightly after the database has been re-indexed.  This uses less memory and also makes the process
      # faster for end users

      # delete firecloud workspace so it can be reused (unless specified by user), and raise error if unsuccessful
      # if successful, we're clear to queue the study for deletion
      if params[:workspace] == 'persist'
        @study.update(firecloud_workspace: nil)
      else
        begin
          Study.firecloud_client.delete_workspace(@study.firecloud_workspace)
        rescue RuntimeError => e
          logger.error "#{Time.now} unable to delete workspace: #{@study.firecloud_workspace}; #{e.message}"
          redirect_to studies_path, alert: "We were unable to delete your study due to: #{e.message}.<br /><br />No files or database records have been deleted.  Please try again later" and return
        end
      end

      # notify users of deletion before removing shares & owner
      SingleCellMailer.study_delete_notification(@study, current_user).deliver_now

      # revoke all study_shares
      @study.study_shares.delete_all

      # queue job to delete study caches
      CacheRemovalJob.new(@study.url_safe_name).delay.perform

      # mark for deletion, rename study to free up old name for use, and restrict access by removing owner
      new_name = "DELETE-#{@study.data_dir}"
      @study.update!(queued_for_deletion: true, public: false, user_id: nil, name: new_name, url_safe_name: new_name)
      update_message = "Study '#{name}'was successfully destroyed. All#{params[:workspace].nil? ? ' workspace data & ' : ' '}parsed database records have been destroyed."

      respond_to do |format|
        format.html { redirect_to studies_path, notice: update_message }
        format.json { head :no_content }
      end
    else
      redirect_to studies_path, alert: 'You do not have permission to perform that action' and return
    end
  end

  # parses file in foreground to maintain UI state for immediate messaging
  def parse
    @study_file = StudyFile.where(study_id: params[:id], upload_file_name: params[:file]).first
    logger.info "#{Time.now}: Parsing #{@study_file.name} as #{@study_file.file_type} in study #{@study.name}"
    case @study_file.file_type
      when 'Cluster'
        @cache_key = render_cluster_url(study_name: @study.url_safe_name, cluster: @study_file.name)
        @study.delay.initialize_cluster_group_and_data_arrays(@study_file, current_user)
      when 'Expression Matrix'
        @study.delay.initialize_expression_scores(@study_file, current_user)
      when 'Gene List'
        @study.delay.initialize_precomputed_scores(@study_file, current_user)
      when 'Metadata'
        @study.delay.initialize_study_metadata(@study_file, current_user)
    end
    changes = ["Study file added: #{@study_file.upload_file_name}"]
    if @study.study_shares.any?
      SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
    end
  end

  # create a new study_file for requested study
  def new_study_file
    file_type = params[:file_type] ? params[:file_type] : 'Cluster'
    @study_file = @study.build_study_file({file_type: file_type})
    @study_file = @study.build_study_file({file_type: file_type})
  end

  # update an existing study file via upload wizard; cannot be called until file is uploaded, so there is no create
  # if adding an external fastq file link, will create entry from scratch to update
  def update_study_file
    @study_file = StudyFile.where(study_id: study_file_params[:study_id], _id: study_file_params[:_id]).first
    if @study_file.nil?
      # don't use helper as we're about to mass-assign params
      @study_file = @study.study_files.build
    end
    @selector = params[:selector]
    @partial = params[:partial]

    # do a test assignment and check for validity; if valid and either Cluster or Gene List, invalidate caches
    @study_file.assign_attributes(study_file_params)
    if ['Cluster', 'Gene List'].include?(@study_file.file_type) && @study_file.valid?
      @study_file.invalidate_cache_by_file_type
    end

    if @study_file.save
      # if a gene list or cluster got updated, we need to update the associated records
      if study_file_params[:file_type] == 'Gene List'
        @precomputed_entry = PrecomputedScore.find_by(study_file_id: study_file_params[:_id])
        @precomputed_entry.update(name: study_file_params[:name])
      elsif study_file_params[:file_type] == 'Cluster'
        @cluster = ClusterGroup.find_by(study_file_id: study_file_params[:_id])
        @cluster.update(name: study_file_params[:name])
        # also update data_arrays
        @cluster.data_arrays.update_all(cluster_name: study_file_params[:name])
      end
      @message = "'#{@study_file.name}' has been successfully updated."

      # notify users of updated file
      changes = ["Study file updated: #{@study_file.upload_file_name}"]
      if @study.study_shares.any?
        SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
      end
    else
      respond_to do |format|
        format.js {render action: 'update_fail'}
      end
    end
  end

  # update an existing study file via sync page
  def update_study_file_from_sync
    @study_file = StudyFile.find_by(study_id: study_file_params[:study_id], _id: study_file_params[:_id])
    if @study_file.nil?
      # don't use helper as we're about to mass-assign params
      @study_file = @study.study_files.build
    end
    @form = "#study-file-#{@study_file.id}"

    # do a test assignment and check for validity; if valid and either Cluster or Gene List, invalidate caches
    @study_file.assign_attributes(study_file_params)
    if ['Cluster', 'Gene List'].include?(@study_file.file_type) && @study_file.valid?
      @study_file.invalidate_cache_by_file_type
    end

    if @study_file.save
      # if a gene list or cluster got updated, we need to update the associated records
      if study_file_params[:file_type] == 'Gene List'
        @precomputed_entry = PrecomputedScore.find_by(study_file_id: study_file_params[:_id])
        @precomputed_entry.update(name: study_file_params[:name])
      elsif study_file_params[:file_type] == 'Cluster'
        @cluster = ClusterGroup.find_by(study_file_id: study_file_params[:_id])
        @cluster.update(name: study_file_params[:name])
        # also update data_arrays
        @cluster.data_arrays.update_all(cluster_name: study_file_params[:name])
      end
      @message = "'#{@study_file.name}' has been successfully updated."

      # notify users of updated file
      changes = ["Study file updated: #{@study_file.upload_file_name}"]
      if @study.study_shares.any?
        SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
      end
    else
      @partial = 'synced_study_file_form'
      respond_to do |format|
        format.js {render action: 'update_fail'}
      end
    end
  end

  # delete the requested study file
  def delete_study_file
    @study_file = StudyFile.find(params[:study_file_id])
    @message = ""
    unless @study_file.nil?
      @file_type = @study_file.file_type
      @message = "'#{@study_file.name}' has been successfully deleted."
      # clean up records before removing file (for memory optimization)
      case @file_type
        when 'Cluster'
          ClusterGroup.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          DataArray.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          @partial = 'initialize_ordinations_form'
        when 'Expression Matrix'
          ExpressionScore.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          DataArray.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          @partial = 'initialize_expression_form'
        when 'Metadata'
          StudyMetadatum.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          @partial = 'initialize_metadata_form'
        when 'Fastq'
          @partial = 'initialize_primary_data_form'
        when 'Gene List'
          PrecomputedScore.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          @partial = 'initialize_marker_genes_form'
        else
          @partial = 'initialize_misc_form'
      end
      # delete matching caches
      @study_file.invalidate_cache_by_file_type
      # delete source file in FireCloud and then remove record
      begin
        # make sure file is in FireCloud first as user may be aborting the upload
        if !Study.firecloud_client.execute_gcloud_method(:get_workspace_file, @study.firecloud_workspace, @study_file.upload_file_name).nil?
          Study.firecloud_client.execute_gcloud_method(:delete_workspace_file, @study.firecloud_workspace, @study_file.upload_file_name)
        end
      rescue RuntimeError => e
        logger.error "#{Time.now}: error in deleting #{@study_file.upload_file_name} from workspace: #{@study.firecloud_workspace}; #{e.message}"
        redirect_to request.referrer, alert: "We were unable to delete #{@study_file.upload_file_name} due to an error: #{e.message}.  Please try again later."
      end
      changes = ["Study file deleted: #{@study_file.upload_file_name}"]
      if @study.study_shares.any?
        SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
      end
      @study_file.destroy

      # reset initialized if needed
      if @study.cluster_ordinations_files.empty? || @study.expression_matrix_file.nil? || @study.metadata_file.nil?
        @study.update(initialized: false)
      end
    else
      # user most likely aborted upload before it began, so determine file type based on form target
      @message = "Upload sucessfully cancelled."
      case params[:target]
        when /expression/
          @file_type = 'Expression Matrix'
          @partial = 'initialize_expression_form'
        when /metadata/
          @file_type = 'Metadata'
          @partial = 'initialize_metadata_form'
        when /ordinations/
          @file_type = 'Cluster'
          @partial = 'initialize_ordinations_form'
        when /fastq/
          @file_type = 'Fastq'
          @partial = 'initialize_primary_data_form'
        when /marker/
          @file_type = 'Gene List'
          @partial = 'initialize_marker_genes_form'
        else
          @file_type = 'Other'
          @partial = 'initialize_misc_form'
      end
    end

    is_required = ['Cluster', 'Expression Matrix', 'Metadata'].include?(@file_type)
    @color = is_required ? 'danger' : 'info'
    @status = is_required ? 'Required' : 'Optional'
    @study_file = @study.build_study_file({file_type: @file_type})

    unless @file_type.nil?
      @reset_status = @study.study_files.select {|sf| sf.file_type == @file_type && !sf.new_record?}.count == 0
    else
      @reset_status = false
    end
  end

  # adding new study_file entries based on remote files in GCP
  def sync_study_file
    @study_file = @study.study_files.build
    if @study_file.update(study_file_params)
      @message = "New Study File '#{@study_file.name}' successfully synced."
      # only grab id after update as it will change on new entries
      @form = "#study-file-#{@study_file.id}"
      @partial = 'study_file_form'
      if @study_file.parseable?
        logger.info "#{Time.now}: Parsing #{@study_file.name} as #{@study_file.file_type} in study #{@study.name} as remote file"
        @message += " You will receive and email at #{current_user.email} when the parse has completed."
        # parse file as appropriate type
        case @study_file.file_type
          when 'Cluster'
            @study.delay.initialize_cluster_group_and_data_arrays(@study_file, current_user, {local: false})
          when 'Expression Matrix'
            @study.delay.initialize_expression_scores(@study_file, current_user, {local: false})
          when 'Gene List'
            @study.delay.initialize_precomputed_scores(@study_file, current_user, {local: false})
          when 'Metadata'
            @study.delay.initialize_study_metadata(@study_file, current_user, {local: false})
        end
      end
      respond_to do |format|
        format.js
      end
    else
      respond_to do |format|
        format.js {render action: 'sync_action_fail'}
      end
    end
  end

  # re-associated a study_file entry in the database with a remote file in GCP that has changed
  def sync_orphaned_study_file
    @study_file = StudyFile.find_by(study_id: study_file_params[:study_id], _id: study_file_params[:_id])
    @form = "#study-file-#{@study_file.id}"
    @partial = 'orphaned_study_file_form'
    # overwrite name with requested file unless study_file is a cluster or gene list
    update_params = study_file_params
    if @study_file.file_type != 'Cluster' && @study_file.file_type != 'Gene List'
      update_params[:name] = params[:existing_file]
    end

    if @study_file.update(update_params)
      @message = "New Study File '#{@study_file.name}' successfully synced."
      # only reparse if user requests
      if @study_file.parseable? && params[:reparse] == 'Yes'
        logger.info "#{Time.now}: Parsing #{@study_file.name} as #{@study_file.file_type} in study #{@study.name} as remote file"
        @message += " You will receive an email "
        case @study_file.file_type
          when 'Cluster'
            @study.delay.initialize_cluster_group_and_data_arrays(@study_file, current_user, {local: false, reparse: true})
          when 'Expression Matrix'
            @study.delay.initialize_expression_scores(@study_file, current_user, {local: false, reparse: true})
          when 'Gene List'
            @study.delay.initialize_precomputed_scores(@study_file, current_user, {local: false, reparse: true})
          when 'Metadata'
            @study.delay.initialize_study_metadata(@study_file, current_user, {local: false, reparse: true})
        end
      end

      respond_to do |format|
        format.js {render action: 'sync_study_file'}
      end
    else
      respond_to do |format|
        format.js {render action: 'sync_action_fail'}
      end
    end
  end

  # similar to delete_study_file, but called when a study_file record has been orphaned (no corresponding bucket file)
  def unsync_study_file
    @study_file = StudyFile.find(params[:study_file_id])
    @message = ""
    unless @study_file.nil?
      @file_type = @study_file.file_type
      @message = "'#{@study_file.name}' has been successfully deleted."
      # clean up records before removing file (for memory optimization)
      case @file_type
        when 'Cluster'
          ClusterGroup.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          DataArray.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
        when 'Expression Matrix'
          ExpressionScore.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
          DataArray.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
        when 'Metadata'
          StudyMetadatum.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
        when 'Gene List'
          PrecomputedScore.where(study_file_id: @study_file.id, study_id: @study.id).delete_all
        else
          nil
      end

      changes = ["Study file deleted: #{@study_file.upload_file_name}"]
      if @study.study_shares.any?
        SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
      end

      # delete matching caches
      @study_file.delay.invalidate_cache_by_file_typ

      if @study_file.destroy
        @message = "'#{@study_file.name}' has been successfully deleted."

        # reset initialized if needed
        if @study.cluster_ordinations_files.empty? || @study.expression_matrix_file.nil? || @study.metadata_file.nil?
          @study.update(initialized: false)
        end
        respond_to do |format|
          format.js {render action: 'sync_action_success'}
        end
      else
        respond_to do |format|
          format.js {render action: 'sync_action_fail'}
        end
      end
    end
  end

  # synchronize a directory_listing object
  def sync_directory_listing
    @directory = DirectoryListing.find(directory_listing_params[:_id])
    if @directory.update(directory_listing_params)
      @message = "Directory listing for '#{@directory.name}' successfully synced."
      @form = "#directory-listing-#{@directory.id}"
      respond_to do |format|
        format.js {render action: 'sync_directory_listing'}
      end
    else
      respond_to do |format|
        format.js {render action: 'sync_action_fail'}
      end
    end
  end

  # delete a directory_listing object
  def delete_directory_listing
    @directory = DirectoryListing.find(params[:directory_listing_id])
    @form = "#directory-listing-#{@directory.id}"
    if @directory.destroy
      @message = "Directory listing for '#{@directory.name}' successfully unsynced."
      respond_to do |format|
        format.js {render action: 'sync_action_success'}
      end
    else
      respond_to do |format|
        format.js {render action: 'sync_action_fail'}
      end
    end
  end

  # method to perform chunked uploading of data
  def do_upload
    upload = get_upload
    filename = upload.original_filename
    study_file = @study.study_files.detect {|sf| sf.upload_file_name == filename}
    # If no file has been uploaded or the uploaded file has a different filename,
    # do a new upload from scratch
    if study_file.nil?
      # don't use helper as we're about to mass-assign params
      study_file = @study.study_files.build
      if study_file.update(study_file_params)
        render json: { file: { name: study_file.errors,size: nil } } and return
        # If the already uploaded file has the same filename, try to resume
      else
        study_file.errors.each do |error|
          logger.error "#{Time.now}: upload failed due to #{error.inspect}"
        end
        head 422 and return
      end
    else
      current_size = study_file.upload_file_size
      content_range = request.headers['CONTENT-RANGE']
      begin_of_chunk = content_range[/\ (.*?)-/,1].to_i # "bytes 100-999999/1973660678" will return '100'

      # If the there is a mismatch between the size of the incomplete upload and the content-range in the
      # headers, then it's the wrong chunk!
      # In this case, start the upload from scratch
      unless begin_of_chunk == current_size
        render json: study_file.to_jq_upload and return
      end
      # Add the following chunk to the incomplete upload, converting to unix line endings
      File.open(study_file.upload.path, "ab") do |f|
        if study_file.upload_content_type == 'text/plain'
          f.write(upload.read.gsub(/\r\n?/, "\n"))
        else
          f.write upload.read
        end
      end

      # Update the upload_file_size attribute
      study_file.upload_file_size = study_file.upload_file_size.nil? ? upload.size : study_file.upload_file_size + upload.size
      study_file.save!

      render json: study_file.to_jq_upload and return
    end
  end

  # GET /courses/:id/resume_upload.json
  def resume_upload
    study_file = StudyFile.where(study_id: params[:id], name: params[:file]).first
    if study_file.nil?
      render json: { file: { name: "/uploads/default/missing.png",size: nil } } and return
    elsif study_file.status == 'uploaded'
      render json: {file: nil } and return
    else
      render json: { file: { name: study_file.upload.url, size: study_file.upload_file_size } } and return
    end
  end

  # update a study_file's upload status to 'uploaded'
  def update_status
    study_file = StudyFile.where(study_id: params[:id], upload_file_name: params[:file]).first
    study_file.update!(status: params[:status])
    head :ok
  end

  # retrieve study file by filename during initializer wizard
  def retrieve_wizard_upload
    @study_file = StudyFile.where(study_id: params[:id], upload_file_name: params[:file]).first
    if @study_file.nil?
      head 404 and return
    end
  end

  # method to download files if study is private, will create temporary signed_url after checking user quota
  # method to download files if study is private, will create temporary signed_url after checking user quota
  def download_private_file
    @study = Study.find_by(url_safe_name: params[:study_name])
    # check if user has permission in case someone is phishing
    if current_user.nil? || !@study.can_view?(current_user)
      redirect_to site_path, alert: 'You do not have permission to perform that action.' and return
    else
      begin
        filesize = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, @study.firecloud_workspace, params[:filename]).size
        user_quota = current_user.daily_download_quota + filesize
        # check against download quota that is loaded in ApplicationController.get_download_quota
        if user_quota <= @download_quota
          @signed_url = Study.firecloud_client.execute_gcloud_method(:generate_signed_url, @study.firecloud_workspace, params[:filename], expires: 15)
          current_user.update(daily_download_quota: user_quota)
        else
          redirect_to view_study_path(@study.url_safe_name), alert: 'You have exceeded your current daily download quota.  You must wait until tomorrow to download this file.' and return
        end
      rescue RuntimeError => e
        logger.error "#{Time.now}: error generating signed url for #{params[:filename]}; #{e.message}"
        redirect_to request.referrer, alert: "We were unable to download the file #{params[:filename]} do to an error: #{e.message}" and return
      end
      # redirect directly to file to trigger download
      redirect_to @signed_url
    end
  end

  # for files that don't need parsing, send directly to firecloud on upload completion
  def send_to_firecloud
    @study_file = StudyFile.find_by(study_id: params[:id], upload_file_name: params[:file])
    @study.delay.send_to_firecloud(@study_file)
    changes = ["Study file added: #{@study_file.upload_file_name}"]
    if @study.study_shares.any?
      SingleCellMailer.share_update_notification(@study, changes, current_user).deliver_now
    end
    head :ok
  end

  # load annotations for a given study and cluster
  def load_annotation_options
    @default_cluster = @study.cluster_groups.detect {|cluster| cluster.name == params[:cluster]}
    @default_cluster_annotations = {
        'Study Wide' => @study.study_metadata.map {|metadata| ["#{metadata.name}", "#{metadata.name}--#{metadata.annotation_type}--study"] }.uniq
    }
    unless @default_cluster.nil?
      @default_cluster_annotations['Cluster-based'] = @default_cluster.cell_annotations.map {|annot| ["#{annot[:name]}", "#{annot[:name]}--#{annot[:type]}--cluster"]}
    end
  end

  def update_default_options
    @study.default_options = default_options_params
    # get new annotation type from parameters
    new_annotation_type = default_options_params[:annotation].split('--')[1]
    # clean up color profile if changing from numeric- to group-based annotation
    if new_annotation_type == 'group'
      @study.default_options[:color_profile] = nil
    end
    if @study.save
      @study.default_cluster.study_file.invalidate_cache_by_file_type
      set_study_default_options
      render action: 'update_default_options_success'
    else
      set_study_default_options
      render action: 'update_default_options_fail'
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_study
    @study = Study.find(params[:id])
  end

  # study params whitelist
  def study_params
    params.require(:study).permit(:name, :description, :public, :user_id, :embargo, :use_existing_workspace, :firecloud_workspace, study_shares_attributes: [:id, :_destroy, :email, :permission])
  end

  # study file params whitelist
  def study_file_params
    params.require(:study_file).permit(:_id, :study_id, :name, :upload, :upload_file_name, :upload_content_type, :upload_file_size, :description, :file_type, :status, :human_fastq_url, :human_data, :cluster_type, :generation, :x_axis_label, :y_axis_label, :z_axis_label, :x_axis_min, :x_axis_max, :y_axis_min, :y_axis_max, :z_axis_min, :z_axis_max)
  end

  def directory_listing_params
    params.require(:directory_listing).permit(:_id, :name, :description, :sync_status)
  end

  def default_options_params
    params.require(:study_default_options).permit(:cluster, :annotation, :color_profile)
  end

  def set_file_types
    @file_types = StudyFile::STUDY_FILE_TYPES.delete_if {|f| f == 'Fastq'}
  end

  # return upload object from study params
  def get_upload
    study_file_params.to_h['upload']
  end

  def check_edit_permissions
    if !user_signed_in? || !@study.can_edit?(current_user)
      redirect_to studies_path, alert: 'You do not have permission to perform that action' and return
    end
  end

  # check on FireCloud API status and respond accordingly
  def check_firecloud_status
    unless Study.firecloud_client.api_available?
      if request.format.html?
        redirect_to studies_path, alert: 'Study workspaces are temporarily unavailable, so we cannot complete your request.  Please try again later.' and return
      elsif request.xhr?
        render template: '/layouts/firecloud_unavailable'
      else
        head 503
      end
    end
  end

  # set up variables for wizard
  def initialize_wizard_files
    @expression_file = @study.expression_matrix_file
    @metadata_file = @study.metadata_file
    @cluster_ordinations = @study.study_files.select {|sf| sf.file_type == 'Cluster'}
    @sub_clusters = @study.study_files.select {|sf| sf.file_type == 'Cluster Coordinates' && sf.cluster_type == 'sub'}
    @marker_lists = @study.study_files.select {|sf| sf.file_type == 'Gene List'}
    @fastq_files = @study.study_files.select {|sf| sf.file_type == 'Fastq'}
    @other_files = @study.study_files.select {|sf| %w(Documentation Other).include?(sf.file_type)}

    # if files don't exist, build them for use later
    if @expression_file.nil?
      @expression_file = @study.build_study_file({file_type: 'Expression Matrix'})
    end
    if @metadata_file.nil?
      @metadata_file = @study.build_study_file({file_type: 'Metadata'})
    end
    if @cluster_ordinations.empty?
      @cluster_ordinations << @study.build_study_file({file_type: 'Cluster'})
    end
    if @marker_lists.empty?
      @marker_lists << @study.build_study_file({file_type: 'Gene List'})
    end
    if @fastq_files.empty?
      @fastq_files << @study.build_study_file({file_type: 'Fastq'})
    end
    if @other_files.empty?
      @other_files << @study.build_study_file({file_type: 'Documentation'})
    end
  end

  # sub-method to iterate through list of GCP bucket files and build up necessary sync list objects
  def process_workspace_bucket_files(files)
    files.each do |file|
      if !%w(.fastq. .fq.).any? {|str| file.name.include?(str)}
        # make sure filename and generation are identical, otherwise we have an unknown file
        study_match = @study_files.detect {|f| (f.upload_file_name == file.name || f.name == file.name) && f.generation == file.generation }
        # make sure file is not acutally a folder by checking its size and name
        if study_match.nil? && file.size > 0
          # create a new entry and default to cluster file (user can change via dropdown)
          unsynced_file = StudyFile.new(study_id: @study.id, name: file.name, file_type: 'Cluster', upload_file_name: file.name, upload_content_type: file.content_type, upload_file_size: file.size, generation: file.generation)
          @unsynced_files << unsynced_file
        elsif !study_match.nil?
          @synced_study_files << study_match
        end
      else
        # we have a fastq file now, so check if we know about it yet
        directory = file.name.include?('/') ? file.name.split('/').first : '/'
        all_dirs = @directories + @unsynced_directories
        existing_dir = all_dirs.detect {|d| d.name == directory}
        # add to list of discovered files
        @files_by_dir[directory] ||= []
        @files_by_dir[directory] << {name: file.name, size: file.size, generation: file.generation}
        if existing_dir.nil?
          dir = @study.directory_listings.build(name: directory, files: [{name: file.name, size: file.size, generation: file.generation}], sync_status: false)
          @unsynced_directories << dir
        elsif existing_dir.files.find {|f| f[:name] == file.name && f[:generation] == file.generation }.nil?
          existing_dir.files << {name: file.name, size: file.size, generation: file.generation}
          existing_dir.sync_status = false
          if @unsynced_directories.map(&:name).include?(existing_dir.name)
            @unsynced_directories.delete(existing_dir)
          end
          @unsynced_directories << existing_dir
        end
      end
    end
  end
end
