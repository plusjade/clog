$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-dropbox'
require "dropbox-api"
require 'mustache'
require 'erb'
require 'json'
require 'fileutils'
require 'pp'

require 'thumbnailer'

config = File.join('config', 'dropbox.json')
config = File.open(config) {|f| JSON.parse(f.read) }

Dropbox::API::Config.app_key    = config["DROPBOX_KEY"]
Dropbox::API::Config.app_secret = config["DROPBOX_SECRET"]
Dropbox::API::Config.mode       = "sandbox"

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :dropbox, config["DROPBOX_KEY"], config["DROPBOX_SECRET"]
end

def ensure_user
  if session[:user]
    @user = session[:user]
    @client = Dropbox::API::Client.new :token => @user['credentials']['token'], :secret => @user['credentials']['secret']
    return true
  end
  @body = erb :login
  halt(erb :master)
end

get '/' do
  ensure_user
  
  files = @client.get_images({
    :path => 'images', 
    :size => :l,
    :make => false
  })
  template = @client.download('template.html')
  Mustache.render(template,{
    :files => files, 
    :username => @user['info']['name']
  })
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do
    session[:user] = env['omniauth.auth'] # => OmniAuth::AuthHash
    redirect '/'
  end
end

get '/auth/failure' do
  puts params[:message]
  redirect '/'
end

get '/logout' do
  session.clear
  redirect '/'
end
