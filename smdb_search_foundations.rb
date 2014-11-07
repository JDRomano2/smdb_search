#!/usr/bin/env ruby
###############################
# smdb_.rb
# Search SemMedDB, given one or more IDs

require 'rubygems'
require 'mysql2'

client = Mysql2::Client.new(:default_file => "/etc/my.cnf", :database => "kb_semanticmedline")

r1 = client.query("SELECT * FROM CONCEPT WHERE PREFERRED_NAME = \"exenatide\"")
concept_ids = Array.new()
r1.each { |x| concept_ids.push(x["CONCEPT_ID"]) }

concept_ids.each do |conc_id|
  puts "concept ID is #{conc_id}"
  r2 = client.query("SELECT * FROM CONCEPT_SEMTYPE WHERE CONCEPT_ID = \"#{conc_id}\"")
  r2.each { |y| puts y }
end

#parse arguments into hash

class SMDB_search

  def initialize(search_terms)
    @search_terms = self.search_terms
  end

  def get_cui_predication_matches(cui, predication)
    
  end

end
