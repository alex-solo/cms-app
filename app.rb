require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

# Returns absolute path of first argument relative to second argument (current working directory by default)
# __FILE__ is the path to the file the code is in
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def users
  YAML::load(File.open("users.yaml"))
end

# get access to data folder and its contents (in arr)
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |file| File.basename(file) }
  erb :index, layout: :layout
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def render_to_html(file_path)
  content = File.read(file_path)
  case File.extname(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    headers["Content-Type"] = "text/html;charset=utf-8"
    render_markdown(content)
  end
end

# Create a new file
get "/new" do
  if !signed_in?
    session[:message] = "You have to be logged in to do that."
    redirect "/"
  end

  erb :new_file
end

get "/signin" do
  erb :signin
end

# See content of file
get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    render_to_html(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Edit a file
get "/:filename/edit" do
  require_signed_in_user

  @file_name = params[:filename]
  file_path =  File.join(data_path, @file_name)
  if File.file?(file_path)
    @content = render_to_html(file_path)
    headers["Content-Type"] = "text/html"
    erb :edit
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Update an exisiting file
post "/:filename/edit" do
  require_signed_in_user

  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  new_text = params[:content]
  File.write(file_path, new_text)

  session[:message] = "#{file_name} has been updated."
  redirect "/"
end

def create_document(name, content="")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

# Add new file to the data folder
post "/create" do
require_signed_in_user

  filename = params[:new_file].strip
  if filename.empty?
    session[:message] = "File name cannot be empty."
    status 422
    erb :new_file
  else
    create_document(filename)
    session[:message] = "#{filename} was created successfully."
    redirect "/"
  end
end

post "/destroy/:filename" do
  require_signed_in_user

  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.delete(file_path)
  session[:message] = "#{filename} has been successfully deleted."
  redirect "/"
end

class PasswordDigester
  def self.check?(password, encrypted_password)
    BCrypt::Password.new(encrypted_password) == password
  end
end

def verify_user(username, password)
  users.has_key?(username) && PasswordDigester.check?(password, users[username])
end

def require_signed_in_user
  unless signed_in?
    session[:message] = "You have to be logged in to do that."
    redirect "/"
  end
end

def signed_in?
  session[:signedin] == true
end

# Submit credentials and sign in
post "/signin" do
  username = params[:username]
  password = params[:password]

  if verify_user(username, password)
    session[:user] = username
    session[:signedin] = true
    session[:message] = "Welcome"
    redirect "/"
  else
    session[:message] = "Invalid Credentials."
    status 422
    erb :signin
  end
end

post "/signout" do
  session[:signedin] = false
  session.delete(:user)
  session[:message] = "You have been signed out"
  redirect "/"
end