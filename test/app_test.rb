ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../app"

def setup
  FileUtils.mkdir_p(data_path)
end

def teardown
  FileUtils.rm_rf(data_path)
end

def create_document(name, content="")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def session
  last_request.env["rack.session"]
end

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    create_document "about.txt"
    create_document "changes.txt"

    get "/"
    assert_equal(200, last_response.status)
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_file_contents
    create_document "about.txt", "Perl, Smalltalk"

    get "/about.txt"
    assert_equal(200, last_response.status)
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Perl, Smalltalk"
  end

  def test_viewing_markdown_document
    create_document "sample.md", "<h1>An h1 header</h1>"

    get "/sample.md"

    assert_equal(200, last_response.status)
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>An h1 header</h1>"
  end

  def test_no_file_found
    get "/randomstringfiledontexit.txt"
  
    assert_equal(302, last_response.status)
    assert_equal "randomstringfiledontexit.txt does not exist.", session[:message]
  end

  def test_edit_file
    create_document "about.txt"

    get "/about.txt/edit"

    assert_equal(200, last_response.status)
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    create_document "test_test.txt"

    post "/test_test.txt/edit", content: "new content"

    assert_equal(302, last_response.status)
    assert_equal("test_test.txt has been updated.", session[:message])

    get "/test_test.txt"

    assert_equal(200, last_response.status)
    assert_includes last_response.body, "new content"
  end

  def test_create_new_file
    get "/new"

    assert_equal(200, last_response.status)
    assert_includes last_response.body, "Add a new"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_submitting_empty_form
    post "/create", new_file: ""

    assert_equal(422, last_response.status)
    assert_includes last_response.body, "File name cannot be empty."
  end

  def test_submitting_valid_filename
    post "/create", new_file: "another_test_one_two.txt"

    assert_equal(302, last_response.status)
    assert_equal("another_test_one_two.txt was created successfully.", session[:message])
  end

  def test_deleting_file
    create_document "brand_brand_new.txt"

    get "/"
    assert_equal(200, last_response.status)
    assert_includes last_response.body, "brand_brand_new.txt"

    post "/destroy/brand_brand_new.txt"

    assert_equal(302, last_response.status)
    assert_equal("brand_brand_new.txt has been successfully deleted.", session[:message])
  end
end