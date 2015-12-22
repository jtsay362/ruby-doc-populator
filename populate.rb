require 'json'
require 'fileutils'
require 'pathname'
require 'uri'
require 'rdoc/rdoc'
require 'set'

OUTPUT_VERSION_MARKER_URI_COMPONENT = '${VERSION}'
VALID_VERSION_MARKER_URI_COMPONENT = '-_VERSION_-'
CORE_BASE_URL = "http://www.ruby-doc.org/core-#{OUTPUT_VERSION_MARKER_URI_COMPONENT}"
STDLIB_BASE_URL = "http://ruby-doc.org/stdlib-#{OUTPUT_VERSION_MARKER_URI_COMPONENT}/libdoc"

# JSON.stringify($('#class-index .entries .class a').map(function (t) { return $(this).text(); }).toArray())
CORE_CLASSES = Set.new(["ConditionVariable","Queue","SizedQueue","Array","Bignum","BasicObject","Object","Module","Class","Complex","Complex::compatible","NilClass","Numeric","String","Float","Fiber","FiberError","Continuation","Dir","File","Encoding","Enumerator","StopIteration","Enumerator::Lazy","Enumerator::Generator","Enumerator::Yielder","Exception","SystemExit","fatal","SignalException","Interrupt","StandardError","TypeError","ArgumentError","IndexError","KeyError","RangeError","ScriptError","SyntaxError","LoadError","NotImplementedError","NameError","NoMethodError","RuntimeError","SecurityError","NoMemoryError","EncodingError","SystemCallError","Encoding::CompatibilityError","File::Stat","IO","ObjectSpace::WeakMap","Hash","ENV","IOError","EOFError","IO::EAGAINWaitReadable","IO::EAGAINWaitWritable","IO::EWOULDBLOCKWaitReadable","IO::EWOULDBLOCKWaitWritable","IO::EINPROGRESSWaitReadable","IO::EINPROGRESSWaitWritable","unknown","RubyVM","RubyVM::InstructionSequence","Math::DomainError","ZeroDivisionError","FloatDomainError","Integer","Fixnum","Data","TrueClass","FalseClass","Thread","Proc","LocalJumpError","SystemStackError","Method","UnboundMethod","Binding","Process::Waiter","Process::Status","Struct","Random","Range","Rational","Rational::compatible","RegexpError","Regexp","MatchData","Symbol","ThreadGroup","Mutex","ThreadError","Time","Encoding::UndefinedConversionError","Encoding::InvalidByteSequenceError","Encoding::ConverterNotFoundError","Encoding::Converter","RubyVM::Env","Thread::Backtrace","Thread::Backtrace::Location","UncaughtThrowError","TracePoint"])

# JSON.stringify($('#class-index .entries .module a').map(function (t) { return $(this).text(); }).toArray())
CORE_MODULES = Set.new(["Comparable", "Kernel", "File::Constants", "Enumerable", "Errno", "FileTest", "GC", "ObjectSpace", "GC::Profiler", "IO::WaitReadable", "IO::WaitWritable", "Marshal", "Math", "Process", "Process::UID", "Process::GID", "Process::Sys", "Signal"])

class ElasticsearchIndexGenerator
  RDoc::RDoc.add_generator self

  attr_reader :classes
  attr_reader :methods
  attr_reader :modsort
  attr_reader :out

  def initialize(store, options)
    @store   = store
    @options = options

    @classes = nil
    @methods = nil
    @modules = nil
    @first_document = true
  end

  # needed for CodeObject.description
  def class_dir
    nil
  end

  def file_dir
    nil
  end

  def generate
    setup

    File.open('ruby_doc.json', 'a:UTF-8') do |out|
      @out = out
      write_classes_and_modules
      write_attributes
      write_methods
      write_constants
    end
  end

  def setup
    @classes = @store.all_classes_and_modules
    @methods = @classes.map { |m| m.method_list }.flatten
    @attributes = @classes.map { |m| m.attributes }.flatten
    @constants = @classes.map { |c| c.constants }.flatten
    @modules = get_module_list @classes
  end

  private

  def write_classes_and_modules
    @modules.each do |mod|
      write_separator
      if mod.module?
        out.write(module_to_hash(mod, true).to_json)
      else
        out.write(class_to_hash(mod, true).to_json)
      end
    end
  end

  def write_separator
    if @first_document
      @first_document = false
    else
      out.write("\n,")
    end
  end


  def write_methods
    @methods.each do |method|
      write_separator
      out.write(method_to_hash(method, nil, true).to_json)
    end
  end

  def write_attributes
    @attributes.each do |a|
      write_separator
      out.write(attribute_to_hash(a, nil, true).to_json)
    end
  end


  def write_constants
    @constants.each do |k|
      write_separator
      out.write(constant_to_hash(k, nil, true).to_json)
    end
  end


  def get_module_list classes
    classes.select do |klass|
      rv = klass.display?

      unless rv
        puts "Would have skipped class #{klass.name}"
      end

      #  Was klass.display? in Darkfish.
      #  Always return true, otherwise we don't get String.
      true
    end
  end

  def code_object_to_hash(c, base_url, page_url, is_outer=false)
    summaryHtml = nil
    if c.comment.class.name == 'RDoc::Comment'
      summaryHtml = process_links(c.description.strip, base_url, page_url)
    end

    obj = {
      name: c.name,
      summaryHtml: summaryHtml
    }

    if is_outer
      parent = c.parent ? c.parent.full_name : nil

      # parent for
      if parent && parent.include?('../')
        parent = nil
      end

      obj.merge!({
        parent: parent,
        fullName: c.full_name,
        baseUrl: base_url,
        project: 'ruby',
        suggest: {
          input: [c.name, c.full_name].uniq,
          output: [c.full_name]
        }
      })
    end

    obj
  end

  def context_to_hash(c, base_url, is_outer=false)
    context_url = base_url + '/' + c.name + '.html'
    obj = code_object_to_hash(c, base_url, context_url, is_outer).merge({
      attributes: sort_hashes_by_name(c.attributes.map { |m| attribute_to_hash(m, context_url, false) }),
      methods: sort_hashes_by_name(c.method_list.map { |m| method_to_hash(m, context_url, false) }),
      extends: c.extends.map { |e| e.full_name }.sort,
      includes: c.includes.map { |mod| mod.full_name }.sort,
      visibility: c.visibility,
      constants: sort_hashes_by_name(c.constants.map { |k| constant_to_hash(k, context_url, false) }),
      uri: context_url
    })

    obj
  end

  def member_to_hash(m, context_url, is_outer=false)
    base_url = make_base_url(m.parent)
    obj = code_object_to_hash(m, base_url, context_url, is_outer)
  end

  def attribute_to_hash(a, context_url=nil, is_outer=false)
    context_url ||= make_context_url_of_member(a)
    obj = member_to_hash(a, context_url, is_outer).merge({
       visibility: a.visibility,
       uri: context_url + '#' + a.aref
    })

    if is_outer
      obj.merge!({
        recognitionKeys: ['com.solveforall.recognition.programming.ruby.Attribute'],
        boost: 0.8
      })
      obj[:suggest][:weight] = 80
    end

    obj
  end

  def method_to_hash(m, context_url=nil, is_outer=false)
    context_url ||= make_context_url_of_member(m)
    obj = member_to_hash(m, context_url, is_outer).merge({
      params: m.param_seq,
      visibility: m.visibility,
      uri: context_url + '#' + m.aref
    })

    if is_outer
      obj.merge!({
        kind: 'method',
        recognitionKeys: ['com.solveforall.recognition.programming.ruby.Method'],
        boost: 1.0
      })
    end

    obj
  end

  def class_to_hash(c, is_outer=false)
    base_url = make_base_url(c)

    superclass = c.superclass

    if superclass.respond_to?(:full_name)
      superclass = superclass.full_name
    end

    obj = context_to_hash(c, base_url, is_outer).merge({
      superClass: superclass
    })

    if is_outer
      obj.merge!({
        kind: 'class',
        recognitionKeys: ['com.solveforall.recognition.programming.ruby.Class'],
        boost: 2.0
      })
      obj[:suggest][:weight] = 200
    end

    obj
  end


  def module_to_hash(mod, is_outer=false)
    base_url = make_base_url(mod)
    obj = context_to_hash(mod, base_url, is_outer)

    if is_outer
      obj.merge!({
        kind: 'module',
        recognitionKeys: ['com.solveforall.recognition.programming.ruby.Module'],
        boost: 2.0
      })
      obj[:suggest][:weight] = 200
    end

    obj
  end

  def constant_to_hash(k, context_url=nil, is_outer=false)
    context_url ||= make_context_url_of_member(k)
    obj = member_to_hash(k, context_url, is_outer).merge({
      value: k.value.to_s,
      uri: context_url + '#' + k.name
    })

    if is_outer
      obj.merge!({
        kind: 'constant',
        recognitionKeys: ['com.solveforall.recognition.programming.ruby.Constant'],
        boost: 0.5
      })
      obj[:suggest][:weight] = 50
    end

    obj
  end

  def process_links(html, base_url, page_url)
    html.gsub(/<a(\s+[^>]*)>([^<]*)<\/a>/) do |match|
      attributes = $1
      inner = $2

      md = attributes.match(/\shref\s*=\s*"\s*\/?([^"]+)"/)

      if md
        href = md[1]

        if href.start_with?('http://') || href.start_with?('https://')
          match
        else
          new_link = '<a href="' + normalize_url(base_url, page_url, href) + '">' + inner + '</a>'
          puts "Link '#{match}' => '#{new_link}'"
          new_link
        end
      else
        puts "Skipping link processing for '#{match}'"
        match
      end
    end
  end

  def sort_hashes_by_name(arr)
    arr.sort_by { |h| h[:name] }
  end

  def make_base_url(context)
    full_name = context.full_name
    subbed_full_name = full_name.gsub('::', '/')
    name = context.name

    path = ''
    if full_name.include?('::')
      last_slash_index = subbed_full_name.rindex('/')
      path = '/' + subbed_full_name[0, last_slash_index]
    end

    base = nil
    if CORE_CLASSES.include?(full_name) || CORE_MODULES.include?(full_name)
      base = CORE_BASE_URL
    else
      first_name = name

      if full_name.include?('::')
        first_slash_index = subbed_full_name.index('/')
        first_name = subbed_full_name[0, first_slash_index]
      end

      base = STDLIB_BASE_URL + '/' + first_name.downcase + '/rdoc'
    end

    base + path
  end

  def make_context_url_of_member(m)
    base_url = make_base_url(m.parent)
    base_url + '/' + m.parent.name + '.html'
  end

  def normalize_url(base_url, context_url, path)
    if path.start_with?('#')
      context_url + path
    else
      begin
        return URI.join(base_url.gsub(OUTPUT_VERSION_MARKER_URI_COMPONENT,  VALID_VERSION_MARKER_URI_COMPONENT) + '/', path).to_s.
          gsub(VALID_VERSION_MARKER_URI_COMPONENT, OUTPUT_VERSION_MARKER_URI_COMPONENT)
      rescue
        return base_url + '/' + path
      end
    end
  end
end


class RubyDocPopulator
  def initialize(input_path, output_filename)
    @input_path = input_path
    @output_filename = output_filename

    @output_path = "out"
    @full_output_filename = File.join(@output_path, @output_filename)
  end


  def populate
    File.open(@full_output_filename, 'w:UTF-8') do |out|
      out.write <<-eos
{
  "metadata" : {
    "settings" : {
      "analysis": {
        "char_filter" : {
          "no_special" : {
            "type" : "mapping",
            "mappings" : [":=>", "#=>", ".=>", "_=>", "(=>", ")=>", "\\\\u0020=>"]
          }
        },
        "analyzer" : {
          "lower_keyword" : {
            "type" : "custom",
            "tokenizer": "keyword",
            "filter" : ["lowercase"],
            "char_filter" : ["no_special"]
          }
        }
      }
    },
    "mapping" : {
      "_all" : {
        "enabled" : false
      },
      "properties" : {
        "name" : {
          "type" : "string",
           "analyzer" : "lower_keyword"
        },
        "fullName" : {
          "type" : "string",
           "analyzer" : "lower_keyword"
        },
        "summaryHtml" : {
          "type" : "string",
          "index" : "no"
        },
        "parent" : {
          "type" : "string",
          "index" : "no"
        },
        "kind" : {
          "type" : "string",
          "index" : "not_analyzed"
        },
        "boost" : {
          "type" : "float",
          "store" : true,
          "null_value" : 1.0,
          "coerce" : false
        },
        "project" : {
          "type" : "string",
          "index" : "not_analyzed"
        },
        "uri" : {
          "type" : "string",
          "index" : "no"
        },
        "visibility" : {
          "type" : "boolean",
          "index" : "no"
        },
        "params" : {
          "type" : "string",
          "index" : "no"
        },
        "value" : {
          "type" : "string",
          "index" : "no"
        },
        "constants" : {
          "type" : "object",
          "enabled" : false
        },
        "methods" : {
          "type" : "object",
          "enabled" : false
        },
        "attributes" : {
          "type" : "object",
          "enabled" : false
        },
        "superClass" : {
          "type" : "string",
          "index" : "no"
        },
        "extends" : {
          "type" : "string",
          "index" : "no"
        },
        "includes" : {
          "type" : "string",
          "index" : "no"
        },
        "suggest" : {
          "type" : "completion",
          "analyzer" : "lower_keyword"
        }
      }
    }
  },
  "updates" : [
    eos
    end

    write_doc_index

    File.open(@full_output_filename, 'a:UTF-8') do |out|
      out.write("]\n}")
    end
  end

  private

  def write_doc_index
    args = ['-o', @output_path, '--force-output', @input_path, '-f', ElasticsearchIndexGenerator.name.downcase, '-V']

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

FileUtils.mkdir_p("out")

populator = RubyDocPopulator.new(input_path, output_filename)

populator.populate()
system("bzip2 -kf out/#{output_filename}")