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
CONFIG_FILE = "/etc/my.cnf"
DATABASE_NAME = "kb_semanticmedline"

#pp options
#pp ARGV

class SMDB_search

  def initialize(options)
    @client = Mysql2::Client.new(:default_file => CONFIG_FILE, :database => DATABASE_NAME)
    @search_terms = options.search_fields
    @show_predications_flag = options.show_predications
    @verbose_flag = options.verbose
    determine_search_type
  end

  def determine_search_type
    case
    when @search_terms.has_key?(:cui) && @search_terms.has_key?(:predicate)
      get_cui_predication_matches
    when @search_terms.has_key?(:preferred_name) && @search_terms.has_key?(:predicate)
      get_pref_predication_matches
    else
      puts "Error!"
    end
  end

  def get_cui_predication_matches
    @cui = @search_terms[:cui]
    @predicate = @search_terms[:predicate]
    
    # get CONCEPT_IDs
    r = @client.query("SELECT * FROM CONCEPT WHERE CUI = \"#{@cui}\"")
    @concept_ids = []
    r.each { |x| @concept_ids.push(x["CONCEPT_ID"]) }
    puts "Matching concept_id(s):"
    pp @concept_ids
    self.concept_to_predication
  end

  def get_pref_predication_matches
    @pref = @search_terms[:preferred_name]
    @predicate = @search_terms[:predicate]
    
    # get CONCEPT_IDs
    r = @client.query("SELECT * FROM CONCEPT WHERE PREFERRED_NAME = \"#{@pref}\"")
    @concept_ids = []
    r.each { |x| @concept_ids.push(x["CONCEPT_ID"]) }
    puts "Matching concept_id(s):"
    pp @concept_ids
    self.concept_to_predication
  end

  def concept_to_predication
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
        r1 = @client.query("SELECT * FROM SENTENCE WHERE SENTENCE_ID = \"#{y["SENTENCE_ID"]}\"")
        sentence_predication_hash[:pmid] = r1.first["PMID"]
        @sentence_predications.push(sentence_predication_hash)
      end
    end
    #pp @sentence_predications

    puts "========================\n"
    puts "[Predicate : Object] matches for entered subject:\n"
    @objects = []
    #@sentence_predications.map { |p| @objects.push("#{p[:subject]}\t #{p[:predicate]}\t #{p[:object]}\t \{PMID: #{p[:pmid]}\}") }
    @sentence_predications.map { |p| @objects.push(:subject => p[:subject], :predicate => p[:predicate], :object => p[:object], :pmid => p[:pmid]) } # I know there is a better way to do this section... Just lazy today.
    @objects.uniq!
    printf("%24s %15s   %-40s %15s\n", "SUBJECT", "PREDICATE", "OBJECT", "PMID")
    @objects.map { |o| printf("%25s %10s   %-45s %15s\n", o[:subject], o[:predicate], o[:object], "\{pmid: #{o[:pmid]}\}") }
  end

end

SMDB_search.new(options)
