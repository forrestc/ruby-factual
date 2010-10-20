require 'net/http'
require 'json'
require 'uri'

module Factual
  class Api
    def initialize(opts)
      @api_key = opts[:api_key]
      @version = opts[:version]
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

    def sort(sorts)
      @sorts = sorts
      return self
    end

    def each_row
      filters_query = "&filters=" + @filters.to_json if @filters
      if @sorts
        sorts_by = "sort_by=" + @sorts.keys.collect{|k| get_field_id(k).to_s}.join(",") 
        sorts_dir = "sort_dir=" + @sorts.values.collect{|v| (v==1) ? 'asc' : 'desc' }.join(",")
        sorts_query = "&" + sorts_by + "&" + sorts_dir
      end

      resp = @adapter.api_call("/tables/#{@table_key}/read.jsaml?limit=999" + filters_query.to_s + sorts_query.to_s)

      @total_rows = resp["response"]["total_rows"]
      rows = resp["response"]["data"]

      # TODO iterator
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
        :fieldId => @field['id'],
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

    def initialize(api_key, version, domain, debug=false)
      @domain = domain
      @base   = "/api/v#{version}/#{api_key}"
      @debug  = debug
    end

    def api_call(url)
      api_url = @base + url
      puts "http://#{@domain}/#{api_url}" if @debug

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
      resp = api_call("/tables/#{table_key}/schema.json")
      return resp["schema"]
    end
  end

  class ApiError < Exception
  end
end
