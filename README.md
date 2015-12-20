Ruby Doc Populator

This Ruby project creates a Semantic Data Collection Changefile that contains
documentation for the Ruby core library.

To run:

  bundle install
  
  ruby populate.rb <source_path> <output_path>

where <source_path> points to where you have the source code of ruby checked out 
(https://github.com/ruby/ruby). <output_path> defaults to ./out if omitted.

This should create the file ruby_doc.json.bz2 in <output_path>, which can be uploaded to
Solve for All as a Semantic Data Collection Changefile.

For more documentation on Semantic Data Collections see
https://solveforall.com/docs/developer/semantic_data_collection

License

This project is licensed with the Apache License, Version 2.0. See LICENSE.
