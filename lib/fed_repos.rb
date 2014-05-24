require 'rubygems'
require 'open-uri'
require 'json'
require 'octokit'
require 'sinatra_auth_github'
require 'dotenv'
require 'sinatra'
require 'csv'
require './lib/organization'

Dotenv.load
Octokit.auto_paginate = true

module FedRepos
  class App < Sinatra::Base

    ORGS_JSON = 'https://government.github.com/organizations.json'

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

    def agencies
      @agencies ||=
        begin
          data = open ORGS_JSON
          data = JSON.parse data.read
          data["governments"]["United States"]
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
        org = Organization.new agency, client
        @organizations.push org unless org.data.nil?
      end
      @organizations.sort_by! {|org| org.data.public_repos }
      @organizations.reverse!
      @organizations
    end

    before do
      authenticate!
    end

    get '/' do
      erb :index, :locals => { :organizations => organizations, :repo_count => repo_count }
    end

    get "/repos.csv" do
      content_type 'application/csv'
      attachment "repos.csv"
      output = CSV.generate do |csv|
        csv << ["owner", "repo", "nwo", "forks", "watchers"]
        organizations.each do |org|
          org.repos.each do |repo|
            csv << [repo.owner.login, repo.name, repo.full_name, repo.forks_count, repo.watchers_count]
          end
        end
      end
      output
    end

  end
end
