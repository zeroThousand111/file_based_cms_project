require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubi"

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end