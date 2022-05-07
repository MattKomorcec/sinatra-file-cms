require 'sinatra'
require 'sinatra/reloader'
require "redcarpet"
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
                       File.expand_path("../test/users.yml", __FILE__)
                     else
                       File.expand_path("../users.yml", __FILE__)
                     end
  YAML.load_file(credentials_path)
end

def render_markdown(file_path)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(File.read(file_path))
end

def render_text(file_path)
  File.read(file_path)
end

def load_file_content(file_path)
  case File.extname(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    render_text(file_path)
  when ".md"
    headers["Content-Type"] = "text/html"
    erb render_markdown(file_path)
  else
    session[:message] = "This file type is not supported."
    redirect "/"
  end
end

def signed_in?(session)
  session[:username]
end

def check_signed_in(session, &block)
  if signed_in?(session)
    block.call
  else
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    BCrypt::Password.new(credentials[username]) == password
  else
    false
  end
end

# Shows all documents in the system
get "/" do
  pattern = File.join(data_path, "*")

  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

# Shows the new document form
get "/new" do
  check_signed_in(session) do
    erb :new_document
  end
end

# Creates a new document
post "/new" do
  check_signed_in(session) do
    file_name = params[:name].strip

    if file_name.size == 0
      session[:message] = "A name is required."
      status 404
      erb :new_document
    else
      file_path = File.join(data_path, file_name)

      File.write(file_path, "")
      session[:message] = "#{file_name} was created."

      redirect "/"
    end
  end
end

# Shows the content of the file
get "/:file" do
  file_path = File.join(data_path, params[:file])

  if File.exist? file_path
    load_file_content(file_path)
  else
    session[:message] = "#{params[:file]} does not exist."
    redirect "/"
  end
end

# Shows the edit document form
get "/:file/edit" do
  check_signed_in(session) do
    file_path = File.join(data_path, params[:file])

    if File.exist? file_path
      @content = File.read(file_path)

      erb :edit
    else
      session[:message] = "#{params[:file]} does not exist."
      redirect "/"
    end
  end
end

# Updates the documents contents
post "/:file/edit" do
  check_signed_in(session) do
    file_path = File.join(data_path, params[:file])
    file_content = params[:file_content]

    File.write(file_path, file_content)

    session[:message] = "#{params[:file]} has been updated."
    redirect "/"
  end
end

# Deletes a file
get "/:file/delete" do
  check_signed_in(session) do
    file_path = File.join(data_path, params[:file])

    File.delete(file_path)

    session[:message] = "#{params[:file]} has been deleted."
    redirect "/"
  end
end

# Displays a sign in form
get "/users/signin" do
  erb :signin
end

# Logs a user in if credentials are correct
post "/users/signin" do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

# Logs a user out and redirects to index
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."

  redirect "/"
end
