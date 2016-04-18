require "sinatra"
require "sinatra/reloader" if development?
require "json"
require 'rest-client'
require "dotenv"
Dotenv.load

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
      when "tomorrow_weather"
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
    elsif text =~ /画像/
      image_url_message_request_body(sender, "")
    elsif text =~ /ショップ/
      generic_structured_message_request_body(sender, *sample_shop_elements)
    else
      text_message_request_body(sender, text)
    end

  RestClient.post(request_endpoint, request_body, content_type: :json, accespt: :json) do |response, request, result, &block|
    p response.body
  end
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
          url: "https://pbs.twimg.com/profile_images/450801182135422976/-69lntRh.jpeg" # url
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
