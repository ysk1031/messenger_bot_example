require "sinatra"
require "sinatra/reloader" if development?

get "/" do
  "Hello, world!"
end

get "/callback" do
  if params["hub.verify_token"] != "aonounkounko"
    return "Error, wrong validation token"
  end
  params["hub.challenge"]
end
