ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Load .env before Rails so Sidekiq and other processes see OPENAI_API_KEY / ANTHROPIC_API_KEY.
# (dotenv-rails loads again later; duplicate load is harmless.)
begin
  require "dotenv"
  Dotenv.load(File.expand_path("../.env", __dir__))
rescue LoadError
end
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load pgvector before ActiveRecord so the vector type is recognized (avoids "unknown OID" for embedding_vector).
require "pgvector"
