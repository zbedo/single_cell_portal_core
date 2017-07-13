Rails.application.routes.draw do
	scope 'single_cell' do

		# portal admin actions
		post 'admin/reset_user_download_quotas', to: 'admin_configurations#reset_user_download_quotas', as: :reset_user_download_quotas
		post 'admin/restart_locked_jobs', to: 'admin_configurations#restart_locked_jobs', as: :restart_locked_jobs
		post 'admin/firecloud_access', to: 'admin_configurations#manage_firecloud_access', as: :manage_firecloud_access
		resources :admin_configurations, path: 'admin'

    # study reporter actions
    get 'reports', to: 'reports#index', as: :reports
    post 'reports/report_request', to: 'reports#report_request', as: :report_request

    # study admin actions
		mount Ckeditor::Engine => 'ckeditor'
    devise_for :users, :controllers => { :omniauth_callbacks => 'users/omniauth_callbacks' }
    resources :studies do
			member do
				get 'upload', to: 'studies#initialize_study', as: :initialize
				get 'sync', to: 'studies#sync_study', as: :sync
        patch 'upload', to: 'studies#do_upload'
        get 'resume_upload', to: 'studies#resume_upload'
        patch 'update_status', to: 'studies#update_status'
        get 'reset_upload', to: 'studies#reset_upload'
        get 'retrieve_upload', to: 'studies#retrieve_upload', as: :retrieve_upload
        get 'retrieve_wizard_upload', to: 'studies#retrieve_wizard_upload', as: :retrieve_wizard_upload
        get 'study_files/new', to: 'studies#new_study_file', as: :new_study_file
				match 'study_files', to: 'studies#update_study_file', via: [:post, :patch], as: :update_study_file
				match 'update_synced_file', to: 'studies#update_study_file_from_sync', via: [:post, :patch], as: :update_study_file_from_sync
				match 'sync_study_file', to: 'studies#sync_study_file', via: [:post, :patch], as: :sync_study_file
				match 'sync_orphaned_study_file', to: 'studies#sync_orphaned_study_file', via: [:post, :patch], as: :sync_orphaned_study_file
				match 'sync_directory_listing', to: 'studies#sync_directory_listing', via: [:post, :patch], as: :sync_directory_listing
				post 'send_to_firecloud', to: 'studies#send_to_firecloud', as: :send_to_firecloud
				delete 'study_files/:study_file_id', to: 'studies#delete_study_file', as: :delete_study_file
				delete 'study_files/unsync/:study_file_id', to: 'studies#unsync_study_file', as: :unsync_study_file
				delete 'directory_listings/:directory_listing_id', to: 'studies#delete_directory_listing', as: :delete_directory_listing
        post 'parse', to: 'studies#parse', as: :parse_study_file
        get 'load_annotation_options', to: 'studies#load_annotation_options', as: :load_annotation_options
        post 'update_default_options', to: 'studies#update_default_options', as: :update_default_options
			end
		end
		# public/private file download links (redirect to signed_urls from Google)
		get 'data/public/:study_name/:filename', to: 'site#download_file', as: :download_file, constraints: {filename: /.*/}
		get 'data/private/:study_name/:filename', to: 'studies#download_private_file', as: :download_private_file, constraints: {filename: /.*/}

		# autocomplete
		resources :expression_score, only: [:show, :index] do
			get :autocomplete_expression_score_gene, on: :collection
		end

		# public site actions
		get 'study/:study_name', to: 'site#study', as: :view_study
		get 'study/:study_name/edit_study_description', to: 'site#edit_study_description', as: :edit_study_description
		match 'study/:study_name/update_settings', to: 'site#update_study_settings', via: [:post, :patch], as: :update_study_settings
		get 'study/:study_name/get_fastq_files', to: 'site#get_fastq_files', as: :get_fastq_files
		get 'study/:study_name/render_cluster', to: 'site#render_cluster', as: :render_cluster
		get 'study/:study_name/get_new_annotations', to: 'site#get_new_annotations', as: :get_new_annotations
    post 'study/:study_name/search', to: 'site#search_genes', as: :search_genes
    get 'study/:study_name/gene_expression/:gene/', to: 'site#view_gene_expression', as: :view_gene_expression, constraints: {gene: /.*/}
    get 'study/:study_name/render_gene_expression_plots/:gene/', to: 'site#render_gene_expression_plots', as: :render_gene_expression_plots, constraints: {gene: /.*/}
    get 'study/:study_name/gene_expression', to: 'site#view_gene_expression_heatmap', as: :view_gene_expression_heatmap
    get 'study/:study_name/gene_set_expression', to: 'site#view_gene_set_expression', as: :view_gene_set_expression
    get 'study/:study_name/render_gene_set_expression_plots', to: 'site#render_gene_set_expression_plots', as: :render_gene_set_expression_plots
		get 'study/:study_name/expression_query', to: 'site#expression_query', as: :expression_query
		get 'study/:study_name/annotation_query', to: 'site#annotation_query', as: :annotation_query
		get 'study/:study_name/annotation_values', to: 'site#annotation_values', as: :annotation_values
    post 'study/:study_name/precomputed_gene_expression', to: 'site#search_precomputed_results', as: :search_precomputed_results
    get 'study/:study_name/precomputed_gene_expression', to: 'site#view_precomputed_gene_expression_heatmap', as: :view_precomputed_gene_expression_heatmap
    get 'study/:study_name/precomputed_results', to: 'site#precomputed_results', as: :precomputed_results
		get 'search', to: 'site#search', as: :search
    get '/', to: 'site#index', as: :site
    root to: 'site#index'
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
