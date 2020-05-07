#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'byebug'

JEKYLL_PATH = "#{__dir__}/../".freeze

# Generate pagination pages for main page.
# copy index.md to as many "page-x.md" pages as are needed, 
# adjusting the page_num value appropriately

# TODO: convert this into a rake task

# read Wax config
config = YAML.load_file("#{JEKYLL_PATH}_config.yml")

# determine number of images, from csv (subtracting one for the header row)
File.foreach(JEKYLL_PATH + '_data/community_archive.csv') {}
image_count = $. - 1

page_count = (image_count/config['pageworth'].to_f).ceil

# delete old page files, in case the number has gone down
Dir.glob("#{JEKYLL_PATH}page*.md").each { |f| File.delete(f) }

if page_count > 1
  index_md = File.read("#{JEKYLL_PATH}index.md")
  index_yaml, index_text = index_md.match(/\A\-\-\-\n(.+?)\n\-\-\-\n(.*)/m)[1..2]

  # parse yaml header
  header = YAML.load(index_yaml)
  (2..page_count).each do |p|
    page_header = header.dup
    page_header['page_num'] = p

    File.open("#{JEKYLL_PATH}page#{p}.md", 'w') do |f|
      f.write("#{page_header.to_yaml}---\n#{index_text}")
    end
  end
end
