$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-dropbox'
require "dropbox-api"
require 'erb'
require 'json'
require 'fileutils'
require 'pp'

config = File.join('config', 'dropbox.json')
config = File.open(config) {|f| JSON.parse(f.read) }

Dropbox::API::Config.app_key    = config["DROPBOX_KEY"]
Dropbox::API::Config.app_secret = config["DROPBOX_SECRET"]
Dropbox::API::Config.mode       = "sandbox"

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :dropbox, config["DROPBOX_KEY"], config["DROPBOX_SECRET"]
end

module Dropbox
  module API
    class Client
      
      def ls_p(path_to_list = '')
        ls(path_to_list)
      rescue Dropbox::API::Error::NotFound
        mkdir(path_to_list)
        []
      end
    end
  end
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


def make_thumbs(size)
  thumbs_path = "thumbs/#{size}"
  thumbs = @client.ls_p(thumbs_path).map {|f| f.path }
  @client.ls.each do |f|
    next unless f.thumb_exists
    next if thumbs.include?(f.path)
    @client.upload "#{thumbs_path}/#{f.path}", f.thumbnail(:size => size)
  end  
end

def get_thumbs(size)
  dict = {}
  @client.ls_p("thumbs/#{size}").each { |t| dict[t.path] = t}
  dict
end

def get_files_with_thumbs(opts)
  opts[:size] ||= :medium
  make_thumbs(opts[:size]) if opts[:make]
  thumbs = get_thumbs(opts[:size])
  files = opts[:path] ? @client.ls(opts[:path]) : @client.ls
  
  files.each do |f|
    next unless f.thumb_exists
    f['thumbs'] = {} unless f['thumbs']
    thumb = thumbs["thumbs/#{opts[:size]}/#{f.path.split('/').pop}"]
    next unless thumb
    f['thumbs']['m'] = thumb.direct_url['url']
  end

  files
end  

get '/' do
  ensure_user
  @files = get_files_with_thumbs(:size => :l, :make => true)
  @body = erb :home
  erb :master
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
