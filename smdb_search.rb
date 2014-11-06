#!/usr/bin/env ruby
###############################
# smdb_search.rb
# Search SemMedDB, given one or more IDs

require 'rubygems'
require 'mysql2'

client = Mysql2::Client.new(:host => "localhost", :username => "root")
