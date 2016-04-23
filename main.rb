require "sinatra"
require "sinatra/reloader" if development?
require "json"
require 'rest-client'
require 'bing-search'
require "dotenv"
Dotenv.load

BingSearch.account_key = ENV["BING_SEARCH_ACCOUNT_KEY"]

get "/" do
  "Hello, world!"
end

get "/callback" do
  if params["hub.verify_token"] != "aonounkounko"
    return "Error, wrong validation token"
  end
  params["hub.challenge"]
end

post "/callback" do
  request_body = JSON.parse(request.body.read)
  messaging_events = request_body["entry"][0]["messaging"]
  messaging_events.each do |event|
    sender = event["sender"]["id"]

    if !event["postback"].nil?
      case event["postback"]["payload"]
      when "today_weather"
        fetch_weather(:today) {|weather| bot_response(sender, "今日は、#{weather}") }
      when "tomorrow_weather"
        fetch_weather(:tomorrow) {|weather| bot_response(sender, "明日は、#{weather}") }
      end
    elsif !event["message"].nil? && !event["message"]["text"].nil?
      text = event["message"]["text"]
      bot_response(sender, text)
    end
  end

  status 201
  body ''
end


def bot_response(sender, text)
  request_endpoint = "https://graph.facebook.com/v2.6/me/messages?access_token=#{ENV["FACEBOOK_PAGE_TOKEN"]}"
  request_body =
    if text =~ /天気/
      button_structured_message_request_body(sender, "いつの天気？", *weather_buttons)
    elsif text =~ /(.+)\s+画像/
      bing_image = BingSearch.image($&, limit: 10).shuffle[0]
      if bing_image.nil?
        text_message_request_body(sender, "残念、画像は見つかりませんでした")
      else
        image_url_message_request_body(sender, bing_image.media_url)
      end
    elsif text =~ /ショップ/
      generic_structured_message_request_body(sender, *sample_shop_elements)
    else
      text_message_request_body(sender, text)
    end

  RestClient.post request_endpoint, request_body, content_type: :json, accespt: :json
end

def text_message_request_body(sender, text)
  {
    recipient: {
      id: sender
    },
    message: {
      text: text
    }
  }.to_json
end

def image_url_message_request_body(sender, url)
  {
    recipient: {
      id: sender
    },
    message: {
      attachment: {
        type: "image",
        payload: {
          url: url
        }
      }
    }
  }.to_json
end

def button_structured_message_request_body(sender, text, *buttons)
  {
    recipient: {
      id: sender
    },
    message: {
      attachment: {
        type: "template",
        payload: {
          template_type: "button",
          text: text,
          buttons: buttons
        }
      }
    }
  }.to_json
end

def generic_structured_message_request_body(sender, *elements)
  {
    recipient: {
      id: sender
    },
    message: {
      attachment: {
        type: "template",
        payload: {
          template_type: "generic",
          elements: elements
        }
      }
    }
  }.to_json
end

def weather_buttons
  [
    {
      type: "postback",
      title: "今日",
      payload: "today_weather"
    },
    {
      type: "postback",
      title: "明日",
      payload: "tomorrow_weather"
    },
    {
      type: "web_url",
      url: "http://www.jma.go.jp/jp/week/319.html",
      title: "その他"
    }
  ]
end

def sample_shop_elements
  [
    {
      title: "Classic White T-Shirt",
      image_url: "http://petersapparel.parseapp.com/img/item100-thumb.png",
      subtitle: "Soft white cotton t-shirt is back in style",
      buttons: [
        {
          type: "web_url",
          url: "https://petersapparel.parseapp.com/view_item?item_id=100",
          title: "View Item"
        },
        {
          type: "web_url",
          url: "https://petersapparel.parseapp.com/buy_item?item_id=100",
          title: "Buy Item"
        }
      ]
    },
    {
      title: "Classic Grey T-Shirt",
      image_url: "http://petersapparel.parseapp.com/img/item101-thumb.png",
      subtitle: "Soft gray cotton t-shirt is back in style",
      buttons: [
        {
          type: "web_url",
          url: "https://petersapparel.parseapp.com/view_item?item_id=101",
          title: "View Item"
        },
        {
          type: "web_url",
          url: "https://petersapparel.parseapp.com/buy_item?item_id=101",
          title: "Buy Item"
        }
      ]
    }
  ]
end

def fetch_weather(date_sym)
  date = {
    today: "今日",
    tomorrow: "明日"
  }

  request_endpoint = "http://weather.livedoor.com/forecast/webservice/json/v1?city=130010"
  RestClient.get request_endpoint do |response, request, result, &block|
    json = JSON.parse response
    weather = "分かりません"
    json["forecasts"].each do |forecast|
      if forecast["dateLabel"] == date[date_sym]
        weather = forecast["telop"]
      end
    end
    yield weather
  end
end
