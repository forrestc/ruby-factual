require 'lib/factual'
require 'test/unit/helper'

class TableTest < Factual::TestCase
  def setup
    api = Factual::Api.new(:api_key => API_KEY, :debug => DEBUG_MODE)

    @table = api.get_table(TABLE_KEY)
  end

  def test_metadata
    assert_equal @table.name, TABLE_NAME
    assert_equal @table.creator, TABLE_OWNER
  end

  def test_each_row
    states = []
    @table.each_row do |state_info|
      fact = state_info['state']
      states << fact.value
    end

    assert_equal states.length, TOTAL_ROWS
  end

  def test_filtering
    row = @table.filter(:two_letter_abbrev => 'WA').find_one
    assert_equal row["state"].value, "Washington"

    row = @table.filter(:two_letter_abbrev => { '$has' => 'a' }).sort(:state => 1).find_one
    assert_equal row["state"].value, "California"
  end

  def test_sorting
    row = @table.sort(:state => 1).find_one
    assert_equal row["state"].value, "California"

    assert_raise Factual::ApiError do 
      # secondary sort will be supported in next release
      row = @table.sort({:state => 1}, {:test_field1 => 1}).find_one
      row["state"].value
    end
  end

  def test_row
    row = @table.find_one
  end

  def test_fact
  end
end
