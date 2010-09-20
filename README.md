## Sample Usage
>     require 'rubygems'
>     gem 'ruby-factual'
>     require 'factual'
>     
>     api = Factual::Api.new(:api_key => "<YOUR_FACTUAL_API_KEY>", :version => 2)
>     
>     table = api.get_table("g9R1u2")
>     puts table.name
>     
>     table.filter(:two_letter_abbrev => "CA").sort(:state => -1)each_row do |state_info|
>       fact = state_info["state"]
>       puts fact.value
>       if fact.input("Kalifornia", :source => "source", :comment => "comment")
>         puts "inputted"
>       end
>     end
