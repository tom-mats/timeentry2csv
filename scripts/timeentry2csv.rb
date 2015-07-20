require 'net/http'
require 'json/pure'
require 'date'
require 'csv'
require 'optparse'

class Redmine
  def initialize(url, username, api_token)
    @url = url
    @username = username
    @token = api_token
  end
  def get(query_string, option = nil)
    uri = URI.parse(@url + "/#{query_string}.json")
    if option
      req = Net::HTTP::Get.new(uri.path + "?#{option}")
    else
      req = Net::HTTP::Get.new(uri.path)
    end
    req.content_type = 'application/json'
    req['X-Redmine-API-Key'] = @token
    res_data = ""
    Net::HTTP.start(uri.host, uri.port){ |http|
      res = http.request(req)
      res_data += res.body
    }
    res_data
  end
  def get_user_id(username)
    data = JSON.parse(self.get("users", "limit=50"))
    data["users"].each{|user|
      if user["login"] == username
        return user["id"]
      end
    }
    nil
  end
  def timeentry(targetuser, start_date, end_date)
    startdate = Date.parse(start_date)
    enddate = Date.parse(end_date)
    user_id = self.get_user_id(targetuser)
    option = "limit=200"
    if user_id
      option += "&user_id=#{user_id}"
    end
    time_entries = JSON.parse(self.get("time_entries", option))
    spent_data = Hash.new
    time_entries["time_entries"].each{|time_entry|
      spent_date = Date.parse(time_entry["spent_on"])
      if (spent_date - startdate) > 0 && (enddate - spent_date > 0)
        spent = time_entry["spent_on"]
        activity = time_entry["activity"]["name"]
        hour = time_entry["hours"]
        if spent_data.has_key?(spent)
          if spent_data[spent].has_key?(activity)
            spent_data[spent][activity] += hour
          else
            spent_data[spent].store(activity, hour)
          end
        else
          spent_data[spent] = {activity => hour}
        end
      end
    }
    spent_data.sort
  end
end

opts = ARGV.getopts("user", "start:2015-04-01", "end:2015-04-30")
unless opts["start"] =~ /\d\d\d\d\-\d\d-\d\d/
  print "unmatched start format, it requires YYYY-MM-DD"
  exit
end
unless opts["end"] =~ /\d\d\d\d\-\d\d-\d\d/
  print "unmatched end format, it requires YYYY-MM-DD"
  exit
end

redmine = Redmine.new(redmine_url, redmine_username, redmine_api_token)
data = redmine.timeentry(opts["user"], opts["start"], opts["end"])
CSV.open(csv_filename, "wb") do |csv|
  data.each{|one_day_data|
    csv << [one_day_data[0], one_day_data[1]["Design"].to_f, one_day_data[1]["Development"].to_f]
  }
end
