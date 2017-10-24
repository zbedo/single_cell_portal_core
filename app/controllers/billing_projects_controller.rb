class BillingProjectsController < ApplicationController

  ###
  #
  # BillingProjectsController.rb - controller to manage FireCloud billing projects and their assigned users
  #
  # Since access is controller by the user's Google account, no access restrictions need to be checked as only
  # the projects and accounts the user has permissions for will be returned.
  #
  ###

  ##
  #
  # FILTERS & SETTINGS
  #
  ##

  respond_to :html, :js, :json
  before_action :create_firecloud_client, except: [:new_user, :billing_project_workspaces]
  before_action :load_service_account, except: [:new_user, :create_user, :delete_user, :storage_estimate]
  before_filter :authenticate_user!

  ##
  #
  # FIRECLOUD BILLING PROJECT MANAGEMENT METHODS
  #
  ##

  # get available billing accounts & projects
  def index
    billing_accounts = @fire_cloud_client.get_billing_accounts
    @accounts = billing_accounts.map {|account| [account['displayName'], account['accountName']]}
    @projects = {}
    billing_projects = @fire_cloud_client.get_billing_projects

    # load user list for each project
    billing_projects.each do |project|
      project_name = project['projectName']
      @projects[project_name] = {
          status: project['creationStatus'],
          members: @fire_cloud_client.get_billing_project_members(project_name)
      }
    end
  end

  # create a firecloud billing project
  def create
    project_name = billing_project_params[:project_name]
    billing_account = billing_project_params[:billing_account]
    begin
      # create project
      @fire_cloud_client.create_billing_project(project_name, billing_account)
      # add portal service account to project
      @fire_cloud_client.add_user_to_billing_project(project_name, 'owner', @portal_service_account)
      redirect_to billing_projects_path, notice: "Your new project '#{project_name}' was successfully created using '#{billing_account}'" and return
    rescue => e
      logger.error "#{Time.now}: Unable to create new billing project #{project_name} due to error: #{e.message}"
      redirect_to billing_projects_path, alert: "We were unable to create your new project due to the following error: #{e.message}'" and return
    end
  end

  # show new user form
  def new_user
  end

  # create a new user inside a billing project
  def create_user
    role = billing_project_user_params[:role]
    email = billing_project_user_params[:email]
    begin
      @fire_cloud_client.add_user_to_billing_project(params[:project_name], role, email)
      redirect_to billing_projects_path, notice: "#{email} has successfully been added to #{params[:project_name]} as #{role}" and return
    rescue => e
      logger.error "#{Time.now}: Unable to add #{email} to #{params[:project_name]} due to error: #{e.message}"
      redirect_to new_billing_project_user_path, alert: "We were unable to add #{email} to #{params[:project_name]} due to the following error: #{e.message}" and return
    end
  end

  # remove a user from a billing project
  def delete_user
    role = params[:role]
    email = params[:email]
    begin
      @fire_cloud_client.delete_user_from_billing_project(params[:project_name], role, email)
      redirect_to billing_projects_path, notice: "#{email} has successfully been removed from #{params[:project_name]} as #{role}" and return
    rescue => e
      logger.error "#{Time.now}: Unable to remove #{email} from #{params[:project_name]} due to error: #{e.message}"
      redirect_to billing_projects_path, alert: "We were unable to remove #{email} from #{params[:project_name]} due to the following error: #{e.message}'" and return
    end
  end

  # get a list of all workspaces in a project
  def workspaces
    @workspaces = Study.firecloud_client.workspaces(params[:project_name])
  end

  # get a workspace's compute permissions
  def edit_workspace_computes
    workspace_acl = Study.firecloud_client.get_workspace_acl(params[:project_name], params[:study_name])
    @acl = {}
    workspace_acl['acl'].each do |user, permissions|
      access_level = permissions['accessLevel']
      if access_level.include?('OWNER')
        next
      else
        @acl[user] = {
            compute_permission: permissions['canCompute'],
            can_share: permissions['canShare'],
            access_level: access_level,
        }
      end
    end
  end

  # update a workspace's compute permissions for a given user
  def update_workspace_computes
    # create new acl, and cast share & compute values to Booleans
    new_acl = Study.firecloud_client.create_workspace_acl(compute_params[:email],
                                                          compute_params[:access_level],
                                                          compute_params[:can_share] == 'true',
                                                          compute_params[:can_compute] == 'true')
    begin
      Study.firecloud_client.update_workspace_acl(params[:project_name], params[:study_name], new_acl)
    rescue => e
      logger.error "#{Time.now}: error in updating acl for #{params[:project_name]}:#{params[:study_name]}: #{e.message}"
    end
  end

  # get a complete rollup of all storage costs for an entire project
  def storage_estimate
    workspaces = Study.firecloud_client.workspaces(params[:project_name])
    @workspaces = {}
    @total_cost = 0.0
    workspaces.each do |workspace|
      workspace_name = workspace['workspace']['name']
      cost_estimate = Study.firecloud_client.get_workspace_storage_cost(params[:project_name], workspace_name)
      actual_cost = cost_estimate['estimate'].gsub(/\$/, '').to_f
      @workspaces[workspace_name] = actual_cost
      @total_cost += actual_cost
    end
  end

  private

  ##
  #
  # SETTERS
  #
  ##

  def billing_project_params
    params.require(:billing_project).permit(:project_name, :billing_account)
  end

  def billing_project_user_params
    params.require(:billing_project_user).permit(:email, :role)
  end

  def create_firecloud_client
    # create client scoped to current user
    @fire_cloud_client = FireCloudClient.new(current_user, 'single-cell-portal')
  end

  def load_service_account
    # load portal service account email for use in view (we don't want to display this in the portal)
    @portal_service_account = Study.firecloud_client.storage_issuer
  end

  def compute_params
    params.require(:compute).permit(:email, :access_level, :can_compute, :can_share)
  end
end

