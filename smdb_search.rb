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
    @show_predications_flag = options.show_predications
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
    puts "Matching concept_id(s):"
    pp @concept_ids

    # get CONCEPT_SEMTYPE_IDs
    @concept_semtype_ids = []
    @concept_ids.each do |cid|
      r = @client.query("SELECT * FROM CONCEPT_SEMTYPE WHERE CONCEPT_ID = \"#{cid}\"")
      r.each { |x| @concept_semtype_ids.push(x["CONCEPT_SEMTYPE_ID"]) }
    end
    puts "Matching concept_semtype_id(s):"
    pp @concept_semtype_ids

    # get PREDICATION_IDs
    puts "Searching for PREDICATION_ARGUMENTs..."
    @predication_ids = []
    @concept_semtype_ids.each do |csid|
      r = @client.query("SELECT * FROM PREDICATION_ARGUMENT WHERE CONCEPT_SEMTYPE_ID = \"#{csid}\"")
      r.each { |x| @predication_ids.push(x["PREDICATION_ID"]) }
    end
    puts "Found #{@predication_ids.length} predication IDs for the concept."
    #pp @predication_ids
    
    # if '-p' flag was set, show the predications
    if @show_predications_flag
      @predication_ids.each do |pid_flag|
        r = @client.query("SELECT * FROM PREDICATION WHERE PREDICATION_ID = \"#{pid_flag}\"")
        r.each { |x| puts x }
      end
    end

    # for each predication_id, see if it uses the desired predicate
    puts "Searching for PREDICATIONs that match..."
    @predication_ids_matching_predicate = []
    @predication_ids.each do |pid|
      r = @client.query("SELECT * FROM PREDICATION WHERE PREDICATION_ID = \"#{pid}\"")
      r.each do |y|
        @predication_ids_matching_predicate.push(y["PREDICATION_ID"]) if y["PREDICATE"] == @predicate
      end
    end
    #pp @predication_ids_matching_predicate

    # get SENTENCE_PREDICATIONs matching these predication ids
    puts "Found #{@predication_ids_matching_predicate.length()} matches for the predicate."
    puts "Searching for the sentences."
    @sentence_predications = []
    @predication_ids_matching_predicate.each do |match|
      r = @client.query("SELECT * FROM SENTENCE_PREDICATION WHERE PREDICATION_ID = \"#{match}\"")
      r.each do |y|
        sentence_predication_hash = {}
        sentence_predication_hash[:subject] = y["SUBJECT_TEXT"]
        sentence_predication_hash[:predicate] = @predicate
        sentence_predication_hash[:object] = y["OBJECT_TEXT"]
        @sentence_predications.push(sentence_predication_hash)
      end
    end
    #pp @sentence_predications

    puts "========================"
    puts "Things that are treated by the concept you entered:"
    @things_it_treats = []
    @sentence_predications.map { |p| @things_it_treats.push(p[:object]) }
    @things_it_treats.uniq!
    puts @things_it_treats
  end

end

SMDB_search.new(options)
