require 'test/unit/helper'
require 'lib/factual'

class AdapterTest < Factual::TestCase
  def setup
    @adapter = Factual::Adapter.new(API_KEY, API_VERSION, API_DOMAIN, DEBUG_MODE)
  end

  def test_corret_request
    url = "/tables/#{TABLE_KEY}/schema.json"

    assert_nothing_raised do
      resp = @adapter.api_call(url)
    end
  end

  def test_wrong_request
    url = "/tables/#{WRONG_KEY}/schema.json"

    assert_raise Factual::ApiError do
      resp = @adapter.api_call(url)
    end
  end

  def test_getting_schema
    schema = @adapter.schema(TABLE_KEY)

    assert_not_nil schema
    assert_equal schema['name'], TABLE_NAME
  end

  def test_reading_table
    resp = @adapter.read_table(TABLE_KEY)
    assert_equal resp['total_rows'], TOTAL_ROWS
  end

  def test_reading_table_with_filter
    resp = @adapter.read_table(TABLE_KEY, {:two_letter_abbrev => 'CA'})
    assert_equal resp['total_rows'], 1
  end

  def test_inputting
    params = {
      :subjectKey => SUBJECT_KEY,
      :value      => 'sample text',
      :fieldId    => STATE_FIELD_ID
    }

    assert_raise Factual::ApiError do
      @adapter.input(TABLE_KEY, params)
    end
  end
end
