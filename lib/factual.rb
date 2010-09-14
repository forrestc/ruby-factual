require 'curl'
require 'json'
require 'uri'

module Factual
  class Api
    def initialize(opts)
      @api_key = opts[:api_key]
      @version = opts[:version]
      @adapter = Adapter.new(@api_key, @version)
    end

    def get_table(table_key)
      Table.new(table_key, @adapter)
    end
  end

  class Table
    attr_accessor :name, :description, :rating, :source, :creator, :total_row_count, :created_at, :updated_at, :fields
    def initialize(table_key, adapter)
      @table_key = table_key
      @adapter = adapter
      @schema = adapter.schema(@table_key)

     [:name, :description, :rating, :source, :creator, :total_row_count, :created_at, :updated_at, :fields].each do |attr|
       key = camelize(attr)
       self.send("#{attr}=", @schema[key]) 
     end

     @fields.each do |f|
       fid = f['id']
       f['field_ref'] = @schema["fieldRefs"][fid.to_s]
     end
    end

    def read(filters=nil)
      filters_query = "filters=" + filters.to_json if filters
      resp = @adapter.api_call("/tables/#{@table_key}/read.jsaml?limit=999&" + filters_query.to_s)

      @total_rows = resp["response"]["total_rows"]
      rows = resp["response"]["data"]

      # TODO iterator
      rows.collect do |row_data|
        Row.new(@adapter, @table_key, @fields, row_data)
      end
    end

    private

    def camelize(str)
      s = str.to_s.split("_").collect{ |w| w.capitalize }.join
      s[0].chr.downcase + s[1..-1]
    end
  end

  class Row
    attr_accessor :subject_key, :subject

    def initialize(adapter, table_key, fields, row_data)
      @subject_key = row_data[0]
      @fields      = fields
      @table_key   = table_key
      @adapter     = adapter

      @subject     = []
      @fields.each_with_index do |f, idx|
        next unless f["isPrimary"]
        @subject << row_data[idx+1]
      end

      @facts_hash  = {}
      @fields.each_with_index do |f, idx|
        next if f["isPrimary"]
        @facts_hash[f["field_ref"]] = Fact.new(@adapter, @table_key, @subject_key, f['id'], row_data[idx+1])
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
    attr_accessor :value, :subject_key, :field_id, :adapter

    def initialize(adapter, table_key, subject_key, field_id, value)
      @value = value 
      @subject_key = subject_key
      @table_key = table_key
      @field_id = field_id
      @adapter = adapter
    end

    def input(value, opts={})
      hash = opts.merge({
        :subjectKey => @subject_key,
        :fieldId => @field_id,
        :value => value
      })
      query_string = hash.to_a.collect{ |k,v| URI.escape(k.to_s) + '=' + URI.escape(v.to_s) }.join('&')

      @adapter.api_call("/tables/#{@table_key}/input.js?" + query_string)
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

    def initialize(api_key, version)
      @base = "http://api.factual.com/v#{version}/#{api_key}"
    end

    def api_call(url)
      api_url = @base + url
      curl = Curl::Easy.new(api_url) do |c|
        c.connect_timeout = CONNECT_TIMEOUT
      end
      curl.http_get

      resp = JSON.parse(curl.body_str)
      raise ApiError.new(resp["error"]) if resp["status"] == "error"
      return resp
    end

    def schema(table_key)
      resp = api_call("/tables/#{table_key}/schema.json")
      return resp["schema"]
    end
  end

  class ApiError < Exception
  end
end
