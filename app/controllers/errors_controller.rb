# Pages d'erreur servies par config.exceptions_app = routes. Hérite de
# ActionController::Base : une erreur ne doit jamais dépendre de la logique de
# ApplicationController.
class ErrorsController < ActionController::Base
  layout "application"

  def not_found
    render_error 404
  end

  def forbidden
    render_error 403
  end

  def unprocessable
    render_error 422
  end

  def server
    render_error 500
  end

  private

  KEYS = { 404 => "not_found", 403 => "forbidden", 422 => "unprocessable", 500 => "server" }.freeze

  def render_error(code)
    @code = code
    @key = KEYS.fetch(code)
    respond_to do |format|
      format.html { render "errors/show", status: code }
      format.any { head code }
    end
  end
end
