class ApplicationController < ActionController::Base
  # Avoid blocking local/dev clients (embedded previews, older Safari, etc.).
  allow_browser versions: :modern if Rails.env.production?
end
