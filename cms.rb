require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

root = File.expand_path("..", __FILE__)

before do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
end

get "/" do
  erb :index
end

get "/:filename" do
  filename = params[:filename]
  file_path = root + "/data/" + filename

  if File.file?(file_path)
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  else
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end
end