# frozen_string_literal: true

# pgvector is required in config/boot.rb so the vector type is registered before ActiveRecord loads.
# This block only verifies at boot that embedding_vector is recognized as a vector type.

Rails.application.config.after_initialize do
  next unless defined?(ActiveRecord::Base)
  begin
    conn = ActiveRecord::Base.connection
    next unless conn.table_exists?(:market_embeddings)
    col = conn.columns(:market_embeddings).find { |c| c.name == "embedding_vector" }
    if col
      type_name = col.sql_type.to_s.downcase
      if type_name.include?("vector")
        Rails.logger.info "[Pgvector] Vector type registered: embedding_vector is #{col.sql_type}"
      else
        Rails.logger.warn "[Pgvector] embedding_vector may not be vector (sql_type=#{col.sql_type}); OID errors may occur."
      end
    end
  rescue StandardError => e
    Rails.logger.warn "[Pgvector] Boot check skipped: #{e.message}"
  end
end
