ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load pgvector before ActiveRecord so the vector type is recognized (avoids "unknown OID" for embedding_vector).
require "pgvector"
