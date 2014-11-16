require 'json'
require 'fileutils'
require 'pathname'

require 'rdoc/rdoc'

require 'rdoc/generator/darkfish'
require 'rdoc/generator/json_index'

#class RDoc::Generator::Darkfish
#  def initialize(store, options)
#    super
#    @json_index = RDoc::Generator::JsonIndex.new(self, options)
#  end
#
#  def generate
#    @json_index.generate
#  end
#end

class ElasticsearchIndexGenerator
  RDoc::RDoc.add_generator self

  attr_reader :classes
  attr_reader :methods
  attr_reader :modsort

  def initialize(store, options)
    @store   = store
    @options = options

    @classes = nil
    @methods = nil
    @modsort = nil
  end

  def generate
    setup

    write_classes
  end

  def setup
    @classes = @store.all_classes_and_modules.sort
    @methods = @classes.map { |m| m.method_list }.flatten.sort
    @modsort = get_sorted_module_list @classes
  end

  def write_modules
    puts ','
    @modsort.each do |mod|
      puts mod.to_json
    end
  end

  def write_classes
    puts ','
    @classes.each do |clazz|
      puts clazz.to_json
    end
  end

  def write_methods
    puts ','
    @methods.each do |method|
      puts method.to_json
    end
  end

  def get_sorted_module_list classes
    classes.select do |klass|
      klass.display?
    end.sort
  end
end


class RubyDocPopulator
  def initialize(input_path, output_filename)
    @input_path = input_path
    @output_filename = output_filename

    @output_path = "out"
  end


  def populate
    File.open(@output_filename, 'w:UTF-8') do |out|
      out.write <<-eos
{
  "metadata" : {
    "mapping" : {
      "_all" : {
        "enabled" : false
      },
      "properties" : {
        "name" : {
          "type" : "multi_field",
          "path" : "just_name",
          "fields" : {
             "rawName" : { "type" : "string", "index" : "not_analyzed" },
             "name" : { "type" : "string", "index" : "analyzed" }
          }
        },
        "description" : {
          "type" : "string",
          "index" : "analyzed"
        },
        "author" : {
          "type" : "object",
          "properties" : {
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "email" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "contributors" : {
          "type" : "object",
          "properties" : {
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "email" : {
              "type" : "string",
              "index" : "no"
            },
            "github" : {
              "type" : "string",
              "index" : "no"
            },
            "url" : {
              "type" : "string",
              "index" : "no"
            },
            "web" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "dist-tags" : {
          "type" : "object",
          "properties" : {
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "version" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "versions" : {
          "type" : "object",
          "properties" : {
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "tag" : {
              "type" : "string",
              "index" : "no"
            },
            "version" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "main" : {
          "type" : "string",
          "index" : "no"
        },
        "maintainers" : {
          "type" : "object",
          "properties" : {
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "email" : {
              "type" : "string",
              "index" : "no"
            },
            "website" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "readmeFilename" : {
          "type" : "string",
          "index" : "no"
        },
        "repository" : {
          "type" : "object",
          "properties" : {
            "author" : {
              "type" : "string",
              "index" : "no"
            },

            "commit_date" : {
              "type" : "date",
              "index" : "no"
            },
            "dist" : {
              "type" : "string",
              "index" : "no"
            },
            "email" : {
              "type" : "string",
              "index" : "no"
            },
            "git" : {
              "type" : "string",
              "index" : "no"
            },
            "github" : {
              "type" : "string",
              "index" : "no"
            },
            "handle" : {
              "type" : "string",
              "index" : "no"
            },
            "id_string" : {
              "type" : "string",
              "index" : "no"
            },
            "job" : {
              "type" : "string",
              "index" : "no"
            },
            "main" : {
              "type" : "string",
              "index" : "no"
            },
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "repository" : {
              "type" : "string",
              "index" : "no"
            },
            "revision" : {
              "type" : "string",
              "index" : "no"
            },
            "private" : {
              "type" : "string",
              "index" : "no"
            },
            "static" : {
              "type" : "string",
              "index" : "no"
            },
            "title" : {
              "type" : "string",
              "index" : "no"
            },
            "type" : {
              "type" : "string",
              "index" : "no"
            },
            "update" : {
              "type" : "string",
              "index" : "no"
            },
            "url" : {
              "type" : "string",
              "index" : "no"
            },
            "version" : {
              "type" : "string",
              "index" : "no"
            },
            "versions" : {
              "type" : "object",
              "properties" : {
                "tag" : {
                  "type" : "string",
                  "index" : "no"
                },
                "version" : {
                  "type" : "string",
                  "index" : "no"
                }
              }
            },
            "web" :  {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "dist" : {
          "type" : "string",
          "index" : "no"
        },
        "email" : {
          "type" : "string",
          "index" : "no"
        },
        "gpg" : {
          "type" : "object",
          "properties" : {
            "fingerprint" : {
              "type" : "string",
              "index" : "no"
            },
            "signature" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "homepage" : {
          "type" : "string",
          "index" : "no"
        },
        "license" : {
          "type" : "string",
          "index" : "no"
        },
        "org" : {
          "type" : "string",
          "index" : "no"
        },
        "path" : {
          "type" : "string",
          "index" : "no"
        },
        "signature" : {
          "type" : "string",
          "index" : "no"
        },
        "bugs" : {
          "type" : "object",
          "properties" : {
            "bugs" : {
              "type" : "string",
              "index" : "no"
            },
            "email" : {
              "type" : "string",
              "index" : "no"
            },
            "license" : {
              "type" : "string",
              "index" : "no"
            },
            "mail" : {
              "type" : "string",
              "index" : "no"
            },
            "name" : {
              "type" : "string",
              "index" : "no"
            },
            "readmeFilename" : {
              "type" : "string",
              "index" : "no"
            },
            "tags" : {
              "type" : "object",
              "properties" : {
                "tag" : {
                  "type" : "string",
                  "index" : "no"
                },
                "version" : {
                  "type" : "string",
                  "index" : "no"
                }
              }
            },
            "versions" : {
              "type" : "object",
              "properties" : {
                "tag" : {
                  "type" : "string",
                  "index" : "no"
                },
                "version" : {
                  "type" : "string",
                  "index" : "no"
                }
              }
            },
            "time" : {
              "type" : "object",
              "properties" : {
                "modified" : {
                  "type" : "date",
                  "index" : "no"
                }
              }
            },
            "url" : {
              "type" : "string",
              "index" : "no"
            },
            "web" : {
              "type" : "string",
              "index" : "no"
            }
          }
        },
        "time" : {
          "type" : "object",
          "properties" : {
            "modified" : {
              "type" : "date",
              "index" : "no"
            }
          }
        },
        "keywords" : {
          "type" : "string",
          "index" : "not_analyzed"
        },
        "stars" : {
          "type" : "integer",
          "store" : true
        },
        "update" : {
          "type" : "string",
          "index" : "no"
        },
        "created" : {
          "type" : "date",
          "store" : true
        },
        "updated" : {
          "type" : "date",
          "store" : true
        }
      }
    }
  },
  "updates" :
    eos

      #out.write(parse_packages().to_json)

      write_doc_index(out)

      out.write("\n}")
    end
  end

  private

  def write_doc_index(out)
    args = ['-o', @output_path, @input_path, '-f', ElasticsearchIndexGenerator.name.downcase, '-V']

    rdoc = RDoc::RDoc.new
    options = rdoc.load_options
    #options.root = Pathname(@input_path)
    #options.op_dir = @output_path
    options.parse(args)

    rdoc.document(options)
  end
end

input_path = nil
output_filename = 'ruby_doc.json'

ARGV.each do |arg|
  if input_path
    output_filename = arg
  else
    input_path = arg
  end
end

puts "input_path = #{input_path}"

`rm -rf out`

populator = RubyDocPopulator.new(input_path, output_filename)

populator.populate()
system("bzip2 -kf #{output_filename}")