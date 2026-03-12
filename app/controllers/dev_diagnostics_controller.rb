# frozen_string_literal: true

class DevDiagnosticsController < ApplicationController
  def api
    return head :not_found unless Rails.env.development?

    render json: ApiDiagnostics.snapshot
  end
end
