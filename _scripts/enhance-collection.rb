#!/usr/bin/env ruby

require 'json'
require 'byebug'

JEKYLL_PATH = "#{__dir__}/../".freeze

# update the collection json to add thumbnail and label fields from 
# item manifests

# TODO: convert this into a rake task

YAML_HEADER = "---\nlayout: none\n---\n".freeze

def parseFile(filename)
  # strip the YAML header
  JSON.parse(
    File.read(filename).sub(YAML_HEADER, '')
  )
end

collectionPath = "#{JEKYLL_PATH}/img/derivatives/iiif/collection/community_archive.json"
collection = parseFile(collectionPath)

collection['manifests'].each do |member|
  manifestPath = member['@id'].sub('{{ \'/\' | absolute_url }}', JEKYLL_PATH)
  manifest = parseFile(manifestPath)
  # add the thumbnail link to the member
  member['thumbnail'] = manifest['thumbnail']
end

File.open(collectionPath,"w") do |f|
  f.write(YAML_HEADER + collection.to_json)
end

puts "Thumbnail links have been added to #{collectionPath}"
