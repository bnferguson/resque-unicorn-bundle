#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'resque/server'

use Rack::ShowExceptions

# Set the AUTH env variable to your basic auth password to protect Resque.
AUTH_PASSWORD = ENV['AUTH']
if AUTH_PASSWORD
  Resque::Server.use Rack::Auth::Basic do |username, password|
    password == AUTH_PASSWORD
  end
end

run Rack::URLMap.new \
  "/resque" => Resque::Server.new
