module TourCMS
  class Connection
    def initialize(marketp_id, private_key, result_type = "raw", debug = false)
      Integer(marketp_id) rescue raise ArgumentError, "Marketplace ID must be an Integer"
      @marketp_id = marketp_id
      @private_key = private_key
      @result_type = result_type
      @debug = debug
      @base_url = "https://api.tourcms.com"
    end  
    
    def api_rate_limit_status(channel = 0)
      request("/api/rate_limit_status.xml", channel)
    end
    
    def list_channels
      request("/p/channels/list.xml")
    end
    
    def show_channel(channel)
      request("/c/channel/show.xml", channel)
    end
    
    def search_tours(params = {}, channel = 0)
      if channel == 0
        request("/p/tours/search.xml", 0, params)
      else
        request("/c/tours/search.xml", channel, params)
      end
    end
    
    def search_hotels_range(params = {}, tour = "", channel = 0)
      if channel == 0
        request("/p/hotels/search_range.xml", 0, params.merge({"single_tour_id" => tour}))
      else
        request("/c/hotels/search_range.xml", channel, params.merge({"single_tour_id" => tour}))
      end
    end
    
    def search_hotels_specific(params = {}, tour = "", channel = 0)
      if channel == 0
        request("/p/hotels/search-avail.xml", 0, params.merge({"single_tour_id" => tour}))
      else
        request("/c/hotels/search-avail.xml", channel, params.merge({"single_tour_id" => tour}))
      end
    end
    
    def list_tours(channel = 0)
      if channel == 0
        request("/p/tours/list.xml")
      else
        request("/c/tours/list.xml", channel)
      end
    end
    
    def list_tour_images(channel = 0)
      if channel == 0
        request("/p/tours/images/list.xml")
      else
        request("/c/tours/images/list.xml", channel)
      end
    end
    
    def show_tour(tour, channel)
      request("/c/tour/show.xml", channel, {"id" => tour})
    end
    
    def show_tour_departures(tour, channel)
      request("/c/tour/datesprices/dep/show.xml", channel, {"id" => tour})
    end
    
    def show_tour_freesale(tour, channel)
      request("/c/tour/datesprices/freesale/show.xml", channel, {"id" => tour})
    end
    
    def show_tour_datesanddeals(tour, channel, params = {})
      request("/c/tour/datesprices/datesndeals/search.xml", channel, params.merge({"id" => tour}))
    end
    alias_method :datesndeals, :show_tour_datesanddeals
    
    def check_availability(tour, channel, params = {})
      request("/c/tour/datesprices/checkavail.xml", channel, params.merge({"id" => tour}))
    end
    
    def start_new_booking(booking_data, channel)
      request("/c/booking/new/start.xml", channel, {}, booking_data, "POST")
    end
    
    def delete_booking(booking, channel, params = {})
      request("/c/booking/delete.xml", channel, params.merge({"booking_id" => booking}), "", "POST")
    end
    
    def commit_new_booking(booking_data, channel)
      request("/c/booking/new/commit.xml", channel, {}, booking_data, "POST")
    end
    
    def show_booking(booking, channel, params = {})
      request("/c/booking/show.xml", channel, params.merge({"booking_id" => booking}))
    end
    
    def cancel_booking(booking_data, channel)
      request("/c/booking/cancel.xml", channel, {}, booking_data, "POST")
    end
    
    private
    
    def generate_signature(path, verb, channel, outbound_time)
      string_to_sign = "#{channel}/#{@marketp_id}/#{verb}/#{outbound_time}#{path}".strip
      
      dig = OpenSSL::HMAC.digest('sha256', @private_key, string_to_sign)
      b64 = Base64.encode64(dig).chomp
      CGI.escape(b64).gsub("+", "%20")
    end
    
    def request(path, channel = 0, params = {}, data = nil, verb = "GET")
      query = params.size > 0 ? "?#{params.to_query}" : ""
      url = @base_url + path + query
      uri = URI.parse url
      req_time = Time.now.utc
      
      signature = generate_signature(path + query, verb, channel, req_time.to_i)
      
      headers = {
        "Content-type" => "text/xml", 
        "charset" => "utf-8", 
        "Date" => req_time.strftime("%a, %d %b %Y %H:%M:%S GMT"), 
        "Authorization" => "TourCMS #{channel}:#{@marketp_id}:#{signature}" 
      }
        
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.set_debug_output($stdout) if @debug
          
      if verb == "GET"
        request = Net::HTTP::Get.new(uri.request_uri, headers)
      elsif verb == "POST"
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = data 
      end
      response = http.start { |http| http.request request }

      @result_type == "raw" ? response : Hash.from_xml(response.body)["response"]
    end
  end
end
