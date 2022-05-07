ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "minitest/reporters"

Minitest::Reporters.use!

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def create_document(name, content = "")
    path = File.join(data_path, name)

    File.open(path, "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"
    create_document "about.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_history_text_document
    create_document "history.txt", "Ruby 0.95 released"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_nonexistent_document
    get "/wrong.txt"
    assert_equal 302, last_response.status
    assert_equal "wrong.txt does not exist.", session[:message]
  end

  def test_renders_markdown_document
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_document_can_be_edited
    time_now = Time.now.to_s # this represents dynamic text added to the file

    create_document "test.txt"

    get "/test.txt", {}, admin_session
    assert_equal 200, last_response.status
    refute_includes last_response.body, time_now # make sure the file doesn't contain the text

    get "/test.txt/edit"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit content of test.txt" # make sure edit page contains the name of the file
    assert_includes last_response.body, "<textarea" # make sure edit page contains the textarea

    post "/test.txt/edit", :file_content => time_now # make a post request, with the dynamic text to be added
    assert_equal 302, last_response.status

    get last_response["Location"] # follow the redirect
    assert_equal 200, last_response.status
    assert_includes last_response.body, "test.txt has been updated" # make sure "/" shows the flash message

    get "/test.txt" # go to the file content again
    assert_equal 200, last_response.status
    assert_includes last_response.body, time_now # make sure the file now DOES contain dynamic text
  end

  def test_new_document_page_renders
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a new document:"
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "<button"
  end

  def test_new_document_can_be_created
    get "/test_document.txt", {}, admin_session
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test_document.txt does not exist."

    post "/new", :name => "test_document.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "test_document.txt was created."
  end

  def test_new_document_name_empty
    post "/new", {:name => "    "}, admin_session
    assert_equal 404, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_document_can_be_deleted
    create_document "to_delete.txt"

    get "/to_delete.txt/delete", {}, admin_session
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "to_delete.txt has been deleted."
  end

  def test_signin_page_renders
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
    assert_includes last_response.body, "<input"
  end

  def test_signin_valid
    post "/users/signin", :username => "admin", :password => "secret"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Welcome"
    assert_includes last_response.body, "Signed in as admin"
    assert_equal "admin", session[:username]
  end

  def test_signin_invalid_credentials
    post "/users/signin", :username => "guest", :password => "wrong"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    post "/users/signin", :username => "admin", :password => "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome!"

    post "/users/signout"
    get last_response["Location"]
    assert_includes last_response.body, "You have been signed out."
    assert_includes last_response.body, "Sign In"
    assert_nil session[:username]
  end

  def test_redirected_when_not_signed_in
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    create_document "about.txt"
    get "/about.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end
