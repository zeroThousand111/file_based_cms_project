require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubi"

get "/" do
  "<p>Getting started.</p>"
end