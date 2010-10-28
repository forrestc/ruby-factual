require 'lib/factual'
require 'test/unit/helper'

class TableTest < Factual::TestCase # :nodoc:
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

    # secondary sort
    row = @table.sort({:test_field1 => 1}, {:state => -1}).find_one
    assert_equal row["state"].value, "Washington"
  end

  def test_each_row
    states = []
    @table.each_row do |row|
      states << row['state'].value
    end

    assert_equal states.length, @table.total_row_count
  end

  def test_paging
    states = []
    @table.page(2, :size => 2).each_row do |row|
      states << row['state'].value
    end

    assert_equal states.length, 2
    assert_not_equal states[0], "California"
  end

  def test_adding_row
    row = @table.add_row('NE', :state => 'Nebraska')
  end

  def test_row
    row = @table.find_one
  end

  def test_fact
  end
end
