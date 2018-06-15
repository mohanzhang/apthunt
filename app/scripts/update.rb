#!/usr/bin/env ruby

Airrecord.api_key = ENV.fetch("AIRTABLE_API_KEY")

class Apt < Airrecord::Table
  self.base_key = ENV.fetch("AIRTABLE_APP_KEY")
  self.table_name = "Availabilities"
end

def scrape_page(page)
  url = URI.join(ENV.fetch("BASE_URL"), "/floor-plans?unitrent_min=&unitrent_max=&bed_type%5B%5D=studio&bed_type%5B%5D=one&availability=0&floornumber_min=&floornumber_max=&wpv_filter_submit=Search&Page=#{page}")
  html = HTTParty.get(url)
  doc = Nokogiri::HTML(html)

  units = doc.css('.unit_details')

  css_lookup = [:unit_number, :bedrooms, :bath, :sq_feet, :price, :availability].map {|k| [k, ".#{k}"]}.to_h
  payload_to_css = {
    "Unit Number" => :unit_number,
    "Bedrooms" => :bedrooms,
    "Bath" => :bath,
    "SQ FT" => :sq_feet,
    "Price" => :price,
    "Availability" => :availability
  }

  fetched = {} # avoid duplicates

  units.each do |unit|
    payload = {}
    payload_to_css.each do |k,v|
      payload[k] = unit.css(css_lookup.fetch(v)).text.strip
    end

    unit_number = payload.fetch("Unit Number")
    return if fetched[unit_number]

    image_url = doc.css('img[alt="Unit ' + payload.fetch("Unit Number") + '"]').attr('src').text
    payload["Floor Plan"] = image_url
    record = Apt.new(payload)
    record.create

    fetched[unit_number] = true
  end
end

scrape_page(1)
scrape_page(2)