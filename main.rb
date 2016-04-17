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
    if !event["message"].nil? && !event["message"]["text"].nil?
      sender = event["sender"]["id"]
      text = event["message"]["text"]
      bot_response(sender, text)
    end
  end

  status 201
  body ''
end


def bot_response(sender, text)
  request_endpoint = "https://graph.facebook.com/v2.6/me/messages?access_token=#{ENV["FACEBOOK_PAGE_TOKEN"]}"
  request_body = {
    recipient: {
      id: sender
    },
    message: {
      text: text
    }
  }.to_json

  RestClient.post(request_endpoint, request_body, content_type: :json, accespt: :json) do |response, request, result, &block|
    p response.body
  end
end
