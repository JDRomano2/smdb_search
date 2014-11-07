#!/usr/bin/env ruby
###############################
# smdb_.rb
# Search SemMedDB, given one or more IDs

require 'rubygems'
require 'mysql2'
require 'optparse'
require_relative 'lib/smdb_options.rb'
require 'pp'

#parse options
options = SMDB_options.parse(ARGV)

#pp options
#pp ARGV

class SMDB_search

  def initialize(options)
    @client = Mysql2::Client.new(:default_file => "/etc/my.cnf", :database => "kb_semanticmedline")
    @search_terms = options.search_fields
    determine_search_type
  end

  def determine_search_type
    case
    when @search_terms.has_key?(:cui) && @search_terms.has_key?(:predicate)
      get_cui_predication_matches
    else
      puts "Error!"
    end
  end

  def get_cui_predication_matches
    puts "we got here"
    @cui = @search_terms[:cui]
    @predicate = @search_terms[:predicate]
    
    # get CONCEPT_IDs
    r = @client.query("SELECT * FROM CONCEPT WHERE CUI = \"#{@cui}\"")
    @concept_ids = []
    r.each { |x| @concept_ids.push(x["CONCEPT_ID"]) }
    pp @concept_ids

    # get CONCEPT_SEMTYPE_IDs
    @concept_semtype_ids = []
    @concept_ids.each do |cid|
      r = @client.query("SELECT * FROM CONCEPT_SEMTYPE WHERE CONCEPT_ID = \"#{cid}\"")
      r.each { |x| @concept_semtype_ids.push(x["CONCEPT_SEMTYPE_ID"]) }
    end
    pp @concept_semtype_ids

    # get PREDICATION_IDs
    @predication_ids = []
    @concept_semtype_ids.each do |csid|
      r = @client.query("SELECT * FROM PREDICATION_ARGUMENT WHERE CONCEPT_SEMTYPE_ID = \"#{csid}\"")
      r.each { |x| @predication_ids.push(x["PREDICATION_ID"]) }
    end
    pp @predication_ids

    # for each predication_id, see if it uses the desired predicate
    @predication_ids_matching_predicate = []
    @predication_ids.each do |pid|
      r = @client.query("SELECT * FROM PREDICATION WHERE PREDICATION_ID = \"#{pid}\"")
      r.each do |y|
        @predication_ids_matching_predicate.push(y["PREDICATION_ID"]) if y["PREDICATE"] == @predicate
      end
    end
    pp @predication_ids_matching_predicate
  end

end

SMDB_search.new(options)
