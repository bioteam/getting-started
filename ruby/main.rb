require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'


# Initialize the client.
client = Google::APIClient.new(
  :application_name => 'GoogleGenomics Ruby Example App',
  :application_version => '1.0.0'
)

# Load client secrets from your client_secrets.json.
client_secrets = Google::APIClient::ClientSecrets.load

flow = Google::APIClient::InstalledAppFlow.new(
  :client_id => client_secrets.client_id,
  :client_secret => client_secrets.client_secret,
  :scope => ['https://www.googleapis.com/auth/genomics']
)

client.authorization = flow.authorize

# Get the genomics API service 
genomics_service = client.discovered_api('genomics', "v1beta2")

# Using the 1000 Genomes Dataset
thousand_genomes_id = '10473108253681171589'
sample = "NA12872"
reference_name = "22"
reference_position = 51003835

#
# This example gets the read bases for NA12878 at specific a position
#

result = client.execute(:api_method => genomics_service.readgroupsets.search,
  :body_object => {
    :datasetIds => [thousand_genomes_id],
    :name => sample},
  :fields => 'readGroupSets(id)')

readgroupsets = result.data.readGroupSets

unless readgroupsets.size == 1
  raise "Searching for #{sample} didnt find the correct number of read group sets"
end

read_group_set_id = readgroupsets.first.id

# 2. Once we have the read group set ID,
# lookup the reads at the position we are interested in
result = client.execute(
  :api_method => genomics_service.reads.search,
  :body_object => {
    :readGroupSetIds => [read_group_set_id],
    :referenceName => reference_name,
    :start => reference_position,
    :end => reference_position+1,
    :pageSize => 1024},
  :fields => 'alignments(alignment,alignedSequence)')

# Hash to hold the base calls at the reference position
# Default value set to 0 
bases = Hash.new(0)

result.data.alignments.each do |aligned_seq|
  # puts "Alignment: #{aligned_seq.alignedSequence}"
  ref_position_in_this_alignment = reference_position - aligned_seq.alignment.position.position
  base_at_reference_position = aligned_seq.alignedSequence[ref_position_in_this_alignment, 1]
  bases["#{base_at_reference_position}"] +=1
end


puts "#{sample} bases on #{reference_name} at #{reference_position} are"
bases.each do |k,v|
  puts "#{k}: #{v}"
end

#
# This example gets the variants for a sample at a specific position
#

# 1. First find the call set ID for the sample

result = client.execute(
  :api_method => genomics_service.callsets.search,
  :body_object => {
    :variantSetIds => [thousand_genomes_id],
    :name => sample},
  :fields => 'callSets(id)')

callsets = result.data.callSets

unless callsets.size == 1
  raise "Searching for #{sample} didnt find the correct number of call sets"
end

call_set_id = callsets.first.id

# 2. Once we have the call set ID,
# lookup the variants that overlap the position we are interested in

result = client.execute(
  :api_method => genomics_service.variants.search,
  :body_object => {
    :callSetIds => [call_set_id],
    :referenceName => reference_name,
    :start => reference_position,
    :end => reference_position+1},
  :fields => 'variants(names,referenceBases,alternateBases,calls(genotype))')

variant = result.data.variants.first
variant_name = variant.names.first

genotype = ""

variant.calls.first.genotype.each do |g|
  if g == 0
    genotype << variant.referenceBases
  else
    genotype << variant.alternateBases[g-1]
  end
end

puts "The called genotype is #{genotype} for #{variant_name}"



