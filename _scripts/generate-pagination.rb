#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'csv'
require 'fileutils'
require 'byebug'

JEKYLL_PATH = "#{__dir__}/../".freeze

# Generate pagination pages for main page.
# copy index.md to as many "page-x.md" pages as are needed, 
# adjusting the page_num value appropriately

# TODO: convert this into a rake task

def count_pages(image_count)
  (image_count/@config['pageworth'].to_f).ceil
end

def write_md(filename, yaml, text)
  File.open(filename, 'w') do |f|
    f.write("#{yaml.to_yaml}---\n#{text}")
  end
end

# read Wax config
@config = YAML.load_file("#{JEKYLL_PATH}_config.yml")

# determine number of images, from csv (subtracting one for the header row)
File.foreach(JEKYLL_PATH + '_data/community_archive.csv') {}
image_count = $. - 1

page_count = count_pages(image_count)

# delete old page files, in case the number has gone down
Dir.glob("#{JEKYLL_PATH}browse/main/page*.md").each { |f| File.delete(f) }

if page_count > 1
  index_md = File.read("#{JEKYLL_PATH}index.md")
  index_yaml, index_text = index_md.match(/\A\-\-\-\n(.+?)\n\-\-\-\n(.*)/m)[1..2]

  # parse yaml header
  header = YAML.load(index_yaml)
  (2..page_count).each do |p|
    page_header = header.dup
    page_header['page_num'] = p

    write_md("#{JEKYLL_PATH}/browse/main/page#{p}.md", page_header, index_text)

  end
end

# location facet pages
places = CSV.read("#{JEKYLL_PATH}_data/places.csv", headers: true)

# delete old facet files
target_dir = "#{JEKYLL_PATH}/browse/locations"
FileUtils.rm_rf(target_dir)
FileUtils.mkdir(target_dir)

# generate new files. The text content doesn't change, the yaml header does.

places.each do |place|
  facet_dir = "browse/locations/#{place['slug']}"
  yaml = {
           'layout' => 'page', 
           'show_title' => true, 
           'title' => place['name'], 
           'location' => place.to_hash,
           'pagination_prefix' => "#{facet_dir}/page"
         }
  FileUtils.mkdir(facet_dir)

  facet_file = "#{facet_dir}/index.md"
  facet_yaml = yaml.dup
  facet_yaml['page_num'] = 1
  points = "[{lat: #{place['lat']}, lng: #{place['lon']}, value: #{place['count']}, name: \\'#{place['name']}\\', slug: \\'#{place['slug']}\\'}]"
  facet_text = "{% include map.html maptype='mapdiv' mapdata='#{points}' mapcentre='#{place['lat']},#{place['lon']}' mapzoom=11 mapmax=1 mapradius=0.02 %}\n\n{% include collection_gallery.html collection='community_archive' %}"

  # write main page for this facet
  write_md(facet_file, facet_yaml, facet_text)

  # write paginated pages
  puts "#{place['name']}: #{place['count']}"
  page_count = count_pages(place['count'].to_i)

  (2..page_count).each do |p|
    facet_yaml = yaml.dup
    facet_yaml['page_num'] = p

    write_md("#{facet_dir}/page#{p}.md", facet_yaml, facet_text)

  end

end