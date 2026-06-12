class SessionsController < ApplicationController
  def new; end

  def create
    user = User.where(active: true).find_by(email: params[:email].to_s.downcase)

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: "Login realizado com sucesso."
    else
      redirect_to new_session_path, alert: "E-mail ou senha invalidos."
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Voce saiu da sua conta."
  end
end
