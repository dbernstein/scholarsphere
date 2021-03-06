# Copyright © 2012 The Pennsylvania State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rdf'
require 'rdf/rdfxml'
require 'rubygems'
require 'action_view'
require 'rainbow'
require 'cucumber'
require 'cucumber/rake/task'
require 'blacklight/solr_helper'

include ActionView::Helpers::NumberHelper
include Blacklight::SolrHelper

namespace :scholarsphere do
  desc "Restore missing user accounts"
  task :restore_users => :environment do
    # Query Solr for unique depositors
    terms_url = "#{ActiveFedora.solr_config[:url]}/terms?terms.fl=depositor_tesim&terms.sort=index&terms.limit=5000&wt=json&omitHeader=true"
    # Parse JSON response (looks like {"terms":{"depositor_tesim":["mjg36",3]}})
    terms_json = open(terms_url).read
    depositor_logins = JSON.parse(terms_json)['terms']['depositor_tesim'] rescue []
    # Filter out doc counts, and leave logins
    depositor_logins.select! { |item| item.is_a? String }
    # Check for depositor User accounts & restore/populate if missing
    depositor_logins.each { |l| User.create(login: l).populate_attributes if User.find_by_login(l).nil? }
    # Then iterate over other User accounts and populate their attributes just in case
    User.all.each do |u|
      # Skip user if already populated earlier
      next if depositor_logins.include? u.login
      u.populate_attributes
    end
  end

  desc "Report users quota in SS"
  task :quota_report => :environment do
    caution_sz = 3000000000   # 3GB
    warning_sz = 5000000000   # 5GB
    problem_sz = 10000000000  # 10GB
    # loop over users in active record
    users = {}
    User.all.each do |u|
      # for each user query get list of documents
      user_files = GenericFile.find( :depositor => u.login )
      # sum the size of the users docs
      sz = 0
      user_files.each do |f|
        #puts number_to_human_size(f.file_size.first.to_i)
        sz += f.file_size.first.to_i
        #puts "#{sz}:#{f.file_size.first}"
      end
      uname = "#{u.login} #{u.name}"
      users = users.merge(uname => sz)
    end
    longest_key = users.keys.max { |a,b| a.length <=> b.length }
    printf "%-#{longest_key.length}s %s".background(:white).foreground(:black), "User", "Space Used"
    puts ""
    users.each_pair do |k,v|
      if v >= problem_sz
        printf "%-#{longest_key.length}s %s".background(:red).foreground(:white).blink, k, number_to_human_size(v)
      elsif v >= warning_sz
        printf "%-#{longest_key.length}s %s".background(:red).foreground(:white), k, number_to_human_size(v)
      elsif v >= caution_sz
        printf "%-#{longest_key.length}s %s".background(:yellow).foreground(:black), k, number_to_human_size(v)
      else
        printf "%-#{longest_key.length}s %s".background(:black).foreground(:white), k, number_to_human_size(v)
      end
      puts ""
    end

  end

  desc "(Re-)Generate the secret token"
  task :generate_secret => :environment do
    include ActiveSupport
    File.open("#{Rails.root}/config/initializers/secret_token.rb", 'w') do |f|
      f.puts "#{Rails.application.class.parent_name}::Application.config.secret_token = '#{SecureRandom.hex(64)}'"
    end
  end

  def blacklight_config
    @config ||= CatalogController.blacklight_config
    @config.default_solr_params = {:qt=>"search", :rows=>100, :fl=>'id'}
    return @config
  end

  def add_advanced_parse_q_to_solr(solr_parameters, req_params = params)
  end

  desc "Characterize all files"
  task :characterize => :environment do
    # grab the first increment of document ids from solr
    resp = query_solr(:q=>"{!lucene q.op=AND df=text}id:#{ScholarSphere::Application.config.id_namespace}\\:* has_model_ssim:*GenericFile*" )
    #get the totalNumber and the size of the current response
    totalNum =  resp["response"]["numFound"]
    idList = resp["response"]["docs"]
    page = 1

    #loop through each page appending the ids to the original list
    while idList.length < totalNum
       page += 1
       resp = query_solr(:q=>"{!lucene q.op=AND df=text}id:#{ScholarSphere::Application.config.id_namespace}\\:* has_model_ssim:*GenericFile*", :page=>page)
       idList = idList + resp["response"]["docs"]
       totalNum =  resp["response"]["numFound"]
    end

    # for each document in the database call characterize
    idList.each { |o| Sufia.queue.push(CharacterizeJob.new o["id"])}
  end


  desc "Re-solrize all objects"
  task :resolrize => :environment do
    Sufia.queue.push(ResolrizeJob.new)
  end

  desc "Execute Continuous Integration build (docs, tests with coverage)"
  task :ci => :environment do
    Rake::Task["jetty:config"].invoke
    Rake::Task["db:migrate"].invoke

    require 'jettywrapper'
    jetty_params = Jettywrapper.load_config.merge({:jetty_home => File.expand_path(File.join(Rails.root, 'jetty'))})

    error = nil
    error = Jettywrapper.wrap(jetty_params) do
      # do not run the js examples since selenium is not set up for jenkins
      ENV['SPEC_OPTS']="-t ~js"      
      Rake::Task['spec'].invoke
      Cucumber::Rake::Task.new(:features) do |t|
        t.cucumber_opts = "--format pretty"
      end
    end
    raise "test failures: #{error}" if error
  end

  namespace :export do
    desc "Dump metadata as RDF/XML for e.g. Summon integration"
    task :rdfxml => :environment do
      raise "rake scholarsphere:export:rdfxml output=FILE" unless ENV['output']
      export_file = ENV['output']
      triples = RDF::Repository.new
      rows = GenericFile.count
      GenericFile.find(:all).each do |gf|
        next unless gf.rightsMetadata.groups["public"] == "read" && gf.descMetadata.content
        RDF::Reader.for(:ntriples).new(gf.descMetadata.content) do |reader|
          reader.each_statement do |statement|
            triples << statement
          end
        end
      end
      unless triples.empty?
        RDF::Writer.for(:rdfxml).open(export_file) do |writer|
          writer << triples
        end
      end
    end
  end

  namespace :harvest do
    desc "Harvest LC subjects"
    task :lc_subjects => :environment do |cmd, args|
      vocabs = ["/tmp/subjects-skos.nt"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs)
    end

    desc "Harvest DBpedia titles"
    task :dbpedia_titles => :environment do |cmd, args|
      vocabs = ["/tmp/labels_en.nt"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs, :predicate => RDF::RDFS.label)
    end

    desc "Harvest DBpedia categories"
    task :dbpedia_categories => :environment do |cmd, args|
      vocabs = ["/tmp/category_labels_en.nt"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs, :predicate => RDF::RDFS.label)
    end

    desc "Harvest LC MARC geographic areas"
    task :lc_geographic => :environment do |cmd, args|
      vocabs = ["/tmp/vocabularygeographicAreas.nt"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs)
    end

    desc "Harvest Geonames cities"
    task :geonames_cities => :environment do |cmd, args|
      vocabs = ["/tmp/cities1000.txt"]
      LocalAuthority.harvest_tsv(cmd.to_s.split(":").last, vocabs, :prefix => 'http://sws.geonames.org/')
    end

    desc "Harvest Lexvo languages"
    task :lexvo_languages => :environment do |cmd, args|
      vocabs = ["/tmp/lexvo_2012-03-04.rdf"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs,
                                 :format => 'rdfxml', 
                                 :predicate => RDF::URI("http://www.w3.org/2008/05/skos#prefLabel"))
    end

    desc "Harvest LC genres"
    task :lc_genres => :environment do |cmd, args|
      vocabs = ["/tmp/authoritiesgenreForms.nt"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs)
    end

    desc "Harvest LC name authorities"
    task :lc_names => :environment do |cmd, args|
      vocabs = ["/tmp/authoritiesnames.nt.skos"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs)
    end

    desc "Harvest LC thesaurus of graphic materials"
    task :lc_graphics => :environment do |cmd, args|
      vocabs = ["/tmp/vocabularygraphicMaterials.nt"]
      LocalAuthority.harvest_rdf(cmd.to_s.split(":").last, vocabs)
    end
  end
end
