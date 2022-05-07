# Sinatra File CMS

This is a small Sinatra app built during RB175 course in Launch School.

It's a simple File CMS, that allows users to view, edit and add files.

To use the app, first add a new user in `users.yml` file, hashing the password using BCrypt.
This can be done inside of IRB.

The above is not necessary, but you won't be able to edit, add or delete files.

To run the app, navigate to the folder and simply run `ruby cms.rb`, the server will
listen on `localhost:4567`.

To run the tests, run `ruby test/cms_test.rb`.