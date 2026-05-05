Rails.application.routes.draw do
  root 'home#index'

  resources :submissions, only: [:index, :show, :create, :destroy], param: :token do
    post 'batch', to: 'submissions#batch_create', on: :collection
    get 'batch', to: 'submissions#batch_show', on: :collection

    # Phase 3 — asset bytes endpoint. logical_name regex allows dots
    # in filenames (e.g. 'wave.vcd') without Rails treating them as
    # format separators.
    # See docs/superpowers/specs/2026-05-05-submission-assets-design.md.
    get 'assets/:logical_name',
        to: 'submission_assets#show',
        constraints: { logical_name: %r{[^/]+} },
        as: :asset
  end

  resources :languages, only: [:index, :show] do
    get 'all', to: 'languages#all', on: :collection
  end

  resources :statuses, only: [:index]

  get 'system_info', to: 'info#system_info'
  get 'config_info', to: 'info#config_info'
  get 'isolate', to: 'info#isolate'
  get 'about', to: 'info#about'
  get 'version', to: 'info#version'
  get 'license', to: 'info#license'
  get 'statistics', to: 'info#statistics'

  post 'authenticate', to: 'sessions#authenticate'
  post 'authorize', to: 'sessions#authorize'

  get 'workers', to: 'health#workers'
end
