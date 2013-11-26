class Trackerific::Parsers::USPS < Trackerific::Parsers::Base
  protected

  def response_error
    @response_error ||= if @response.code != 200
      Trackerific::Error.new("HTTP returned status #{@response.code}")
    elsif @response['Error']
      Trackerific::Error.new(@response['Error']['Description'])
    elsif @response['TrackResponse'].nil? && @response['CityStateLookupResponse'].nil?
      Trackerific::Error.new("Invalid response from server.")
    else
      false
    end
  end

  def summary
    tracking_info['TrackSummary']
  end

  def events
    tracking_info.fetch('TrackDetail', []).map do |e|
      Trackerific::Event.new(date(e), description(e), location(e))
    end
  end

  private

  def tracking_info
    @response['TrackResponse']['TrackInfo']
  end

  def date(event) 
    months = { "January" => 0, "Feburary" => 1, "March" => 2, "April" => 3, "May" => 4, "June" => 5, "July" => 6, "August" => 7, "September" => 8, "October" => 9, "November" => 10, "December" => 11 }
    
    d = event.split(" ")
    event_hash = Hash[d.map.with_index.to_a]

    month_name = d.find { |element| months[element] }    
    start_value = event_hash[month_name]

    if d[start_value + 4].present? # set end of range based on am/pm presence
      if d[start_value + 4].include?("am") || d[start_value + 4].include?("pm")

        end_value = start_value + 4
      else
        end_value = start_value + 2
      end
    else
      end_value = start_value + 2
    end

    g = DateTime.parse(d[start_value..end_value].join(" "))
  end

  def description(event)
    # description is always the first thing, separated by a comma from the date
    d = event.split(",").first
  end

  def location(event)
    d = event.gsub(".", "").split(" ")

    if d.last.include?("201") #detecting year 2013/2014/etc., no location present
      city, state, zip = ["", "", ""]
    else
      event_hash = Hash[d.map.with_index.to_a]

      starting_index = event_hash["2013,"] if event_hash["2013,"].present?
      starting_index = event_hash["2014,"] if event_hash["2014,"].present?
      starting_index = event_hash["am,"] if event_hash["am,"].present?
      starting_index = event_hash["pm,"] if event_hash["pm,"].present?

      package_location_array = d[starting_index + 1..d.length]

      zip = package_location_array.last
      state = package_location_array[package_location_array.length - 2]
      city = package_location_array - [state, zip]
      city = city.join(" ")
    end

    "#{city} #{state} #{zip}"
  end
end
