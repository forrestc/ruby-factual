# A Ruby Lib for using Facutal API 
#
# For more information, visit http://github.com/factual/ruby-lib (TODO), 
# and {Factual Developer Tools}[http://www.factual.com/devtools]
#
# Author:: Forrest Cao (mailto:forrest@factual.com)
# Copyright:: Copyright (c) 2010 {Factual Inc}[http://www.factual.com].
# License:: GPL

require 'net/http'
require 'json'
require 'uri'

module Factual
  # The start point of using Factual API
  class Api

    # To initialize a Factual::Api, you will have to get an api_key from {Factual Developer Tools}[http://www.factual.com/developers/api_key]
    #
    # Params: opts as a hash
    # * <tt>opts[:api_key]</tt> required
    # * <tt>opts[:debug]</tt>   optional, default is false. If you set it as true, it will print the Factual Api Call URLs on the screen
    # * <tt>opts[:version]</tt> optional, default value is 2, just do not change it
    # * <tt>opts[:domain]</tt>  optional, default value is www.factual.com (only configurable by Factual employees) 
    # 
    # Sample: 
    #   api = Factual::Api.new(:api_key => MY_API_KEY, :debug => true)
    def initialize(opts)
      @api_key = opts[:api_key]
      @version = opts[:version] || 2
      @domain  = opts[:domain] || 'www.factual.com'
      @debug   = opts[:debug]

      @adapter = Adapter.new(@api_key, @version, @domain, @debug)
    end

    # Get a Factual::Table object by inputting the table_key
    #
    # Sample: 
    #   api.get_table('g9R1u2')
    def get_table(table_key)
      Table.new(table_key, @adapter)
    end
  end

  # This class holds the metadata of a Factual table. The filter and sort methods are to filter and/or sort
  # the table data before calling a find_one or each_row.
  class Table
    attr_accessor :name, :key, :description, :rating, :source, :creator, :total_row_count, :created_at, :updated_at, :fields, :geo_enabled, :downloadable
    attr_reader   :adapter # :nodoc:

    def initialize(table_key, adapter) # :nodoc:
      @table_key = table_key
      @adapter   = adapter
      @schema    = adapter.schema(@table_key)
      @key       = table_key

     [:name, :description, :rating, :source, :creator, :total_row_count, :created_at, :updated_at, :fields, :geo_enabled, :downloadable].each do |attr|
       k = camelize(attr)
       self.send("#{attr}=", @schema[k]) 
     end

     @fields.each do |f|
       fid = f['id']
       f['field_ref'] = @schema["fieldRefs"][fid.to_s]
     end
    end

    # Define table filters, it can be chained before +find_one+ or +each_row+.
    # 
    # The params can be:
    # * simple hash for equal filter
    # * nested hash with filter operators
    #
    # Samples:
    #   table.filter(:state => 'CA').find_one # hash
    #   table.filter(:state => 'CA', :city => 'LA').find_one # multi-key hash
    #   table.filter(:state => {"$has" => 'A'}).find_one  # nested hash
    #   table.filter(:state => {"$has" => 'A'}, :city => {"$ew" => 'A'}).find_one # multi-key nested hashes
    #   
    # For more detail inforamtion about filter syntax, please look up at {Server API Doc for Filter}[http://wiki.developer.factual.com/Filter]
    def filter(filters)
      @filters = filters
      return self
    end

    # Define table sorts, it can be chained before +find_one+ or +each_row+.
    # 
    # The params can be:
    # * a hash with single key
    # * single-key hashes, only the first 2 sorts will work. (secondary sort will be supported in next release of Factual API)
    #
    # Samples:
    #   table.sort(:state => 1).find_one  # hash with single key
    #   table.sort({:state => 1}, {:abbr => -1}).find_one # single-key hashes
    # For more detail inforamtion about sort syntax, please look up at {Server API Doc for Sort (TODO)}[http://wiki.developer.factual.com/Sort]
    def sort(*sorts)
      @sorts = sorts
      return self
    end

    # Find the first row (a Factual::Row object) of the table with filters and/or sorts.
    #
    # Samples:
    # * <tt>table.filter(:state => 'CA').find_one</tt>
    # * <tt>table.filter(:state => 'CA').sort(:city => 1).find_one</tt>
    def find_one
      resp = @adapter.read_table(@table_key, @filters, @sorts, 1)
      row_data = resp["data"].first

      if row_data
        return Row.new(self, row_data)
      else
        return nil
      end
    end

    # An iterator on each row (a Factual::Row object) of the filtered and/or sorted table data
    #
    # Samples:
    #   table.filter(:state => 'CA').sort(:city => 1).each do |row|
    #     puts row.inspect
    #   end
    def each_row
      resp = @adapter.read_table(@table_key, @filters, @sorts)

      @total_rows = resp["total_rows"]
      rows = resp["data"]

      rows.each do |row_data|
        row = Row.new(self, row_data) 
        yield(row) if block_given?
      end
    end

    # TODO
    def add_row(values)
    end

    private

    def camelize(str)
      s = str.to_s.split("_").collect{ |w| w.capitalize }.join
      s[0].chr.downcase + s[1..-1]
    end
  end

  # This class holds the subject_key, subject (in array) and facts (Factual::Fact objects) of a Factual Subject. 
  #
  # The subject_key and subject array can be accessable directly from attributes, and you can get a fact by <tt>row[field_ref]</tt>.
  class Row
    attr_reader :subject_key, :subject

    def initialize(table, row_data) # :nodoc:
      @subject_key = row_data[0]

      @table       = table
      @fields      = @table.fields
      @table_key   = @table.key
      @adapter     = @table.adapter

      @subject     = []
      @fields.each_with_index do |f, idx|
        next unless f["isPrimary"]
        @subject << row_data[idx+1]
      end

      @facts_hash  = {}
      @fields.each_with_index do |f, idx|
        next if f["isPrimary"]
        @facts_hash[f["field_ref"]] = Fact.new(@table, @subject_key, f, row_data[idx+1])
      end
    end

    # Get a Factual::Fact object by field_ref
    #
    # Sample: 
    #   city_info = table.filter(:state => 'CA').find_one
    #   city_info['city_name']
    def [](field_ref)
      @facts_hash[field_ref]
    end

    # TODO
    def input(values)
      
    end
  end

  # This class holds the subject_key, value, field_ref field (field metadata in hash). The input method is for suggesting a new value for the fact.  
  class Fact
    attr_reader :value, :subject_key, :field_ref, :field 

    def initialize(table, subject_key, field, value) # :nodoc:
      @value = value 
      @field = field
      @subject_key = subject_key

      @table_key = table.key
      @adapter   = table.adapter
    end

    def field_ref # :nodoc:
      @field["field_ref"]
    end

    # To input a new value to the fact
    #
    # Parameters:
    #  * +value+ 
    #  * <tt>opts[:source]</tt> the source of an input, can be a URL or something else
    #  * <tt>opts[:comment]</tt> the comment of an input
    #
    # Sample:
    #   fact.input('new value', :source => 'http://website.com', :comment => 'because it is new value.'
    def input(value, opts={})
      return false if value.nil?

      hash = opts.merge({
        :subjectKey => @subject_key,
        :fieldId    => @field['id'],
        :value      => value
      })

      @adapter.input(@table_key, hash)
      return true
    end

    # Just return the value
    def to_s
      @value
    end

    # Just return the value
    def inspect
      @value
    end
  end


  class Adapter # :nodoc:
    CONNECT_TIMEOUT = 30

    def initialize(api_key, version, domain, debug=false)
      @domain = domain
      @base   = "/api/v#{version}/#{api_key}"
      @debug  = debug
    end

    def api_call(url)
      api_url = @base + url
      puts "[Factual API Call] http://#{@domain}#{api_url}" if @debug

      json = "{}"
      begin
        Net::HTTP.start(@domain, 80) do |http|
          response = http.get(api_url)
          json     = response.body
        end
      rescue Exception => e
        raise ApiError.new(e.to_s + " when getting " + api_url)
      end

      resp = JSON.parse(json)
      raise ApiError.new(resp["error"]) if resp["status"] == "error"
      return resp
    end

    def schema(table_key)
      url  = "/tables/#{table_key}/schema.json"
      resp = api_call(url)

      return resp["schema"]
    end

    def read_table(table_key, filters=nil, sorts=nil, limit=999)
      filters_query = "&filters=" + filters.to_json if filters

      if sorts
        sorts = sorts[0] if sorts.length == 1
        sorts_query = "&sort=" + sorts.to_json
      end

      url  = "/tables/#{table_key}/read.jsaml?limit=#{limit}" + filters_query.to_s + sorts_query.to_s
      resp = api_call(url)

      return resp["response"]
    end

    def input(table_key, params)
      query_string = params.to_a.collect{ |k,v| URI.escape(k.to_s) + '=' + URI.escape(v.to_s) }.join('&')

      url  = "/tables/#{table_key}/input.js?" + query_string
      resp = api_call(url)

      return resp['response']
    end
  end

  # Exception class for Factual Api Errors  
  class ApiError < Exception
  end
end
