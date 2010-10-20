require 'net/http'
require 'json'
require 'uri'

module Factual
  class Api
    def initialize(opts)
      @api_key = opts[:api_key]
      @version = opts[:version] || 2
      @domain  = opts[:domain] || 'www.factual.com'
      @debug   = opts[:debug]

      @adapter = Adapter.new(@api_key, @version, @domain, @debug)
    end

    def get_table(table_key)
      Table.new(table_key, @adapter)
    end
  end

  class Table
    attr_accessor :name, :description, :rating, :source, :creator, :total_row_count, :created_at, :updated_at, :fields, :geo_enabled, :downloadable
    attr_accessor :key, :adapter

    def initialize(table_key, adapter)
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

    def filter(filters)
      @filters = filters
      return self
    end

    # Define sort before find_one or each_row
    # the params can be:
    #  * a hash with one key, table.sort(:state => 1).find_one
    #  * an array of one-key hash, table.sort({:state => 1}, {:abbr => -1}).find_one, only the secondary sort will be take effect. (it will be supported in next release)
    #
    # For more detail inforamtion, please look up at http://wiki.developer.factual.com/Sort
    def sort(*sorts)
      @sorts = sorts
      return self
    end

    def find_one
      resp = @adapter.read_table(@table_key, @filters, @sorts, 1)
      row_data = resp["data"].first

      if row_data
        return Row.new(self, row_data)
      else
        return nil
      end
    end

    def each_row
      resp = @adapter.read_table(@table_key, @filters, @sorts)

      @total_rows = resp["total_rows"]
      rows = resp["data"]

      rows.each do |row_data|
        row = Row.new(self, row_data) 
        yield(row) if block_given?
      end
    end

    private

    def get_field_id(field_ref)
      @fields.each do |f|
        return f['id'] if f['field_ref'] == field_ref.to_s
      end
    end

    def camelize(str)
      s = str.to_s.split("_").collect{ |w| w.capitalize }.join
      s[0].chr.downcase + s[1..-1]
    end
  end

  class Row
    attr_accessor :subject_key, :subject

    def initialize(table, row_data)
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

    def [](field_ref)
      @facts_hash[field_ref]
    end

    # TODO
    def input(values)
      
    end
  end

  class Fact
    attr_accessor :value, :subject_key, :field, :adapter

    def initialize(table, subject_key, field, value)
      @value = value 
      @field = field
      @subject_key = subject_key

      @table_key = table.key
      @adapter   = table.adapter
    end

    def field_ref
      @field["field_ref"]
    end

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

    def to_s
      @value
    end

    def inspect
      @value
    end
  end


  class Adapter
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

  class ApiError < Exception
  end
end
