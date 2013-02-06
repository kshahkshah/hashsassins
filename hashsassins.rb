require 'sinatra'
require 'debugger'
require "sinatra/reloader" if development?

require 'omniauth'
require 'omniauth-twitter'
require './db_connection'

also_reload './game'
also_reload './user'
also_reload './target'

use Rack::Session::Cookie, :key => 'hashsassins',
                           :path => '/',
                           :expire_after => 14400,
                           :secret => ""# PROVIDE A SECRET
use OmniAuth::Builder do
  provider :twitter, '', '' # YOU PROVIDE TOKEN, YOU PROVIDE SECRET
end

get '/' do
  erb :index
end

get '/auth/twitter/callback' do
  auth = request.env["omniauth.auth"]

  user = User.first_or_create({
    :uid        => auth["uid"],
    :nickname   => auth["info"]["nickname"],
    :name       => auth["info"]["name"],
    :token      => auth["credentials"]["token"],
    :secret     => auth["credentials"]["secret"]
  })

  session[:user_id] = user.id
  redirect '/'
end

helpers do
  def current_user
    @current_user ||= User.where(id: session['user_id']).first if session['user_id']
  end
end