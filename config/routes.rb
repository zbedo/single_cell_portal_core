Rails.application.routes.draw do

	scope 'single_cell' do

		# admin actions
		mount Ckeditor::Engine => 'ckeditor'
    devise_for :users, :controllers => { :omniauth_callbacks => 'users/omniauth_callbacks' }
    resources :studies do
			member do
        get 'upload', to: 'studies#initialize_study', as: :initialize
        patch 'upload', to: 'studies#do_upload'
        get 'resume_upload', to: 'studies#resume_upload'
        patch 'update_status', to: 'studies#update_status'
        get 'reset_upload', to: 'studies#reset_upload'
        get 'retrieve_upload', to: 'studies#retrieve_upload', as: :retrieve_upload
        get 'retrieve_wizard_upload', to: 'studies#retrieve_wizard_upload', as: :retrieve_wizard_upload
        get 'study_files/new', to: 'studies#new_study_file', as: :new_study_file
        match 'study_files', to: 'studies#update_study_file', via: [:post, :patch], as: :update_study_file
				get 'get_bucket_files', to: 'studies#get_bucket_files', as: :get_bucket_files
				post 'send_to_firecloud', to: 'studies#send_to_firecloud', as: :send_to_firecloud
				delete 'study_files/:study_file_id', to: 'studies#delete_study_file', as: :delete_study_file
        post 'parse', to: 'studies#parse', as: :parse_study_file
			end
		end
		# public/private file download links (redirect to signed_urls from Google)
		get 'data/public/:study_name/:filename', to: 'site#download_file', as: :download_file, constraints: {filename: /.*/}
		get 'fastq_data/public/:study_name/:filename', to: 'site#download_fastq_file', as: :download_fastq_file, constraints: {filename: /.*/}
		get 'data/private/:study_name/:filename', to: 'studies#download_private_file', as: :download_private_file, constraints: {filename: /.*/}
		get 'fastq_data/private/:study_name/:filename', to: 'studies#download_private_fastq_file', as: :download_private_fastq_file, constraints: {filename: /.*/}

		# autocomplete
		resources :expression_score, only: [:show, :index] do
			get :autocomplete_expression_score_gene, on: :collection
		end

		# public site actions
		get 'study/:study_name', to: 'site#study', as: :view_study
		get 'study/:study_name/get_fastq_files', to: 'site#get_fastq_files', as: :get_fastq_files
		get 'render_cluster/:study_name', to: 'site#render_cluster', as: :render_cluster
		get 'study/:study_name/get_new_annotations', to: 'site#get_new_annotations', as: :get_new_annotations
    post 'study/:study_name/search', to: 'site#search_genes', as: :search_genes
    get 'study/:study_name/gene_expression/:gene/', to: 'site#view_gene_expression', as: :view_gene_expression, constraints: {gene: /.*/}
    get 'study/:study_name/render_gene_expression_plots/:gene/', to: 'site#render_gene_expression_plots', as: :render_gene_expression_plots, constraints: {gene: /.*/}
    get 'study/:study_name/gene_expression', to: 'site#view_gene_expression_heatmap', as: :view_gene_expression_heatmap
    get 'study/:study_name/gene_set_expression', to: 'site#view_gene_set_expression', as: :view_gene_set_expression
    get 'study/:study_name/render_gene_set_expression_plots', to: 'site#render_gene_set_expression_plots', as: :render_gene_set_expression_plots
		get 'study/:study_name/expression_query', to: 'site#expression_query', as: :expression_query
		get 'study/:study_name/annotation_query', to: 'site#annotation_query', as: :annotation_query
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
