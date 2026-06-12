class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :current_company

  private

  def authenticate_user!
    redirect_to new_session_path, alert: "Entre para continuar." unless current_user
  end

  def current_user
    @current_user ||= User.includes(:company).find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_company
    current_user&.company
  end

  def require_admin!
    redirect_to root_path, alert: "Acesso permitido apenas para administradores." unless current_user&.admin?
  end
end
