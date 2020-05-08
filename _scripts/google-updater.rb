#!/usr/bin/env ruby

require 'active_support/inflector'
require 'geocoder'
require 'google/apis/sheets_v4'
require 'google/apis/drive_v2'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'csv'
require 'uri'
require 'open-uri'
require 'byebug'

INPUT_HEADERS = %w[timestamp name name_visible terms upload label description
             _date location location_slug license free_location lat lon].freeze
HEADERS = (%w[pid] + INPUT_HEADERS).freeze

JEKYLL_PATH = "#{__dir__}/../".freeze
STORE_PATH = "#{JEKYLL_PATH}/../community-archive-store".freeze

# ensure folders have been created
FileUtils.mkdir_p("#{STORE_PATH}/archive")
FileUtils.mkdir_p("#{JEKYLL_PATH}/_data/raw_images")

CREDENTIALS_PATH = "#{STORE_PATH}/credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "#{STORE_PATH}/token.yaml".freeze

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'Community Archive Jekyll'.freeze

SCOPE = [
  Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY,
  Google::Apis::DriveV2::AUTH_DRIVE_READONLY
].freeze

# TODO move this into _config
SHEET = '1HJNrLxk7gKYoEKQXEKLL5pgcpC55gGaZI_OJKrJrLhc'.freeze # community archive spreadsheet

# Class to authenticate access to Google and pull data and images
class Updater
  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
    user_id = "default"
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def initialize
    # Initialize the API
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize

    @drive_service = Google::Apis::DriveV2::DriveService.new
    @drive_service.client_options.application_name = APPLICATION_NAME
    @drive_service.authorization = authorize
  end

  def fetch
    spreadsheet_id = SHEET
    range = "A2:J" # this range gets 10 columns, starting on row 2
    @response = @service.get_spreadsheet_values spreadsheet_id, range
    puts "No data found." if @response.values.empty?
  end

  def process
    # load previous data
    csvpath = File.file?("#{JEKYLL_PATH}/_data/community_archive.csv") ? "#{JEKYLL_PATH}/_data/community_archive.csv" : "#{JEKYLL_PATH}/_data/community_archive_template.csv"
    # data = CSV.parse(File.read(csvpath), headers: true, write_headers: true, return_headers: true)
    data = CSV.parse(File.read(csvpath), headers: true)
    places = {}
    new_row_count = 0

    @response.values.each do |row|
      newrow = CSV::Row.new(INPUT_HEADERS, row)

      # parse the timestamp
      newrow['timestamp'] = Time.strptime("#{newrow['timestamp']} Canada/Edmonton", '%m/%d/%Y %H:%M:%S %Z').to_s

      # geocode the location
      location = newrow['location']
      puts location
      result = Geocoder.search("#{location}, Alberta, Canada")
      if result
        geo = result.first
        puts "-> #{geo.place_id} #{geo.display_name}: #{geo.coordinates}"
        # add [user-submitted location, lat, lon] as last columns
        newrow['free_location'] = location
        newrow['lat'] = geo.coordinates[0]
        newrow['lon'] = geo.coordinates[1]

        # and use normalized place name for location
        normalized_location = geo.display_name.sub(/, Alberta, Canada$/, '')
        newrow['location'] = normalized_location
        slug = ActiveSupport::Inflector::parameterize(normalized_location)
        newrow['location_slug'] = slug
        if places[geo.place_id]
          places[geo.place_id][4] += 1
        else
          places[geo.place_id] =
            [geo.place_id,
             normalized_location,
             slug,
             geo.coordinates[0],
             geo.coordinates[1],
             1]
        end
      end

      # extract the pid and put in the first column
      uri = URI.parse(row[4]) # e.g. https://drive.google.com/open?id=19Y6JNH_Zhckqs2XdVgXe0v8z3UwSxmN0
      pid = Hash[URI.decode_www_form(uri.query)]['id']
      newrow['pid'] = pid

      # download image, unless it already exists
      filename = "#{JEKYLL_PATH}/_data/raw_images/community_archive/#{pid}.jpeg"
      unless File.exists? filename
        puts "Downloading image #{row[4]}"
        @drive_service.get_file(pid, download_dest: filename)
      end

      # create new data row, unless it already exists
      old_row = data.find { |row| row['pid'] == pid }
      unless old_row
        data << newrow
        new_row_count += 1
      end
    end

    # save places
    CSV.open("#{JEKYLL_PATH}/_data/places.csv", 'wb') do |csv|
      csv << %w[id name slug lat lon count]
      places.keys.sort.each do |key|
        csv << places[key]
      end
    end

    puts "New rows: #{new_row_count}"
    return unless new_row_count.nonzero?    

    # back up existing data file and save new version
    if File.file?("#{JEKYLL_PATH}/_data/community_archive.csv")
      ts = Time.now.strftime('%Y-%m-%d_%H-%M-%S_%Z')
      FileUtils.mv(
        "#{JEKYLL_PATH}/_data/community_archive.csv",
        "#{STORE_PATH}/archive/community_archive_#{ts}.csv"
      )
    end

    CSV.open("#{JEKYLL_PATH}/_data/community_archive.csv", 'w') do |f|
      f << data.headers
      # sort rows by timestamp, descending
      data.sort { |a, b| b['timestamp'] <=> a['timestamp']}.each do |row|
        f << row
      end
    end
    puts 'Saved _data/community_archive.csv'
  end
end

updater = Updater.new
updater.fetch
updater.process
