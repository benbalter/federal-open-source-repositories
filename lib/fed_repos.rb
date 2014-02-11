require 'rubygems'
require 'open-uri'
require 'json'
require 'octokit'
require 'sinatra_auth_github'
require 'dotenv'
require 'sinatra'
require './lib/organization'

Dotenv.load
Octokit.auto_paginate = true

module FedRepos
  class App < Sinatra::Base

    REGISTRY_API = 'http://registry.usa.gov/accounts.json?service_id=github'

    set :root, File.dirname(File.dirname(__FILE__))

    use Rack::Session::Cookie, {
      :http_only => true,
      :secret => ENV['SESSION_SECRET'] || SecureRandom.hex
    }

    set :github_options, {
      :scopes    => nil,
      :secret    => ENV['GITHUB_CLIENT_SECRET'],
      :client_id => ENV['GITHUB_CLIENT_ID']
    }

    register Sinatra::Auth::Github

    def client
      @client ||= Octokit::Client.new(:access_token => env['warden'].user.token)
    end

    # require ssl
    configure :production do
      require 'rack-ssl-enforcer'
      use Rack::SslEnforcer
    end

    def agencies
      @agencies ||=
        begin
          data = open REGISTRY_API
          data = JSON.parse data.read
          data["accounts"]
        rescue
          []
        end
    end

    def repo_count
      count = 0
      organizations.each { |org| count = count + org.data.public_repos }
      count
    end

    def organizations
      return @organizations unless @organizations.nil?
      @organizations = []
      agencies.each do |agency|
        org = Organization.new agency["account"], client
        @organizations.push org unless org.data.nil?
      end
      @organizations
    end

    before do
      authenticate!
    end

    get '/' do
      erb :index, :locals => { :organizations => organizations, :repo_count => repo_count }
    end

  end
end
