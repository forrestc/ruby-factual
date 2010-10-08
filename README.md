## Sample Usage

A block of code is worth a thousand words.
>     require 'rubygems'
>     gem 'ruby-factual'
>     require 'factual'
>     
>     api = Factual::Api.new(:api_key => "<YOUR_FACTUAL_API_KEY>", :version => 2)
>     
>     # get table and its metadata
>     # table metadata: name, description, rating, source, creator, created_at,
>     #                 updated_at, total_row_count, geo_enabled, downloadable, 
>     #                 fields (array of hash)
>     table = api.get_table("g9R1u2")
>     puts table.name, table.creator
>     
>     # read rows after filtering and sorting
>     table.filter(:two_letter_abbrev => "CA").sort(:state => -1).each_row do |state_info|
>
>       # read facts
>       # fact attributes: value, subject_key, field_ref, field (hash)
>       fact = state_info["state"]
>       puts fact.value, fact.subject_key
>
>       # write facts
>       if fact.input("Kalifornia", :source => "source", :comment => "comment")
>         puts "inputted"
>       end
>     end
