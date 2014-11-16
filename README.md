Ruby Doc Populator

This Ruby project creates a Semantic Data Collection Changefile that contains
documentation for the Ruby core library.

To run:

  bundle install
  
  ruby populate.rb <source_path> <output_path>

should create the file ruby_doc.json.bz2, which can be uploaded to
Solve for All as a Semantic Data Collection Changefile.

For more documentation on Semantic Data Collections see
https://solveforall.com/docs/developer/semantic_data_collection

