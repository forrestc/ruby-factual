== Sample Usage ==
> require 'ruby-factual'
> 
> api = Factual::Api.new(:api_key => '<YOUR_FACTUAL_API_KEY>', :version => 2)
> 
> table = api.get_table('g9R1u2')
> puts table.name
> 
> table.read(:state => 'hawaii').each do |row|
>   fact = row['test_field']
>   puts fact.value
>   if fact.input('the corrected value', :source => 'source', :comment => 'comment')
>     puts 'inputted'
>   end
> end
