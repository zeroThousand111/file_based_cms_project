require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubi"
require "redcarpet"
require "psych"
require "bcrypt"

SUPPORTED_EXTENSIONS = [".txt", ".md"].freeze

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def filename_already_exists?(new_filename)
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  @files.include?(new_filename)
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  Psych.load_file(credentials_path)
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/new" do
  require_signed_in_user
  erb :new
end

post "/create" do
  require_signed_in_user

  filename = params[:filename].to_s
  supported_extensions = [".txt", ".md"]

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif File.extname(filename) == "" # or if filename has no extension
    session[:message] = "A file extension is required."
    status 422
    erb :new
  elsif !SUPPORTED_EXTENSIONS.include?(File.extname(filename)) # extension not supported
    session[:message] = "The #{File.extname(filename)} extension is not currently supported."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)
    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created."
    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    status 422
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user
  
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."

  redirect "/"
end

post "/:filename/copy" do
  require_signed_in_user
  # get file path of original document
  original_file_path = File.join(data_path, params[:filename])
  # initialise filename of duplicate file
  extension = File.extname(original_file_path)
  basename = File.basename(original_file_path, extension)
  new_filename = "#{basename}_copy#{extension}"

  # check to see if new_filename already exists and return message if it does, halting the duplication process
  if filename_already_exists?(new_filename)
    session[:message] = "Sorry, #{new_filename} already exists."
    redirect "/"
  else
    # get file path of duplicate document
    new_file_path = File.join(data_path, new_filename)
    # get content of original document
    content = File.read(original_file_path)
    # duplicate file with contents of original file???
    File.write(new_file_path, content)
    # session message
    session[:message] = "#{params[:filename]} has been duplicated as #{new_filename}."
    # redirect back to index
    redirect "/"
  end
end
