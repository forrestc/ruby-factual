require 'test/unit'

module Factual
  class TestCase < Test::Unit::TestCase
    # api_key for demo, read-only 
    API_KEY     = 'Jo8cwSHeGQNIWoWRWt569vHS1JiAtiCIy4pbsr9THxmaxdj008fN7QH9rR5lsnMb'
    API_VERSION = 2
    API_DOMAIN  = 'www.factual.com'
    DEBUG_MODE  = false

    TABLE_KEY   = 'g9R1u2'
    TABLE_NAME  = 'us_states_two_letter_abbrevs'
    TABLE_OWNER = 'gil'
    WRONG_KEY   = '$1234$'
    TOTAL_ROWS  = 5

    STATE_FIELD_ID = 14
    SUBJECT_KEY    = 'HELHLPlaobdmCbWFs0uva1AdcT4'

    def test_default
    end
  end
end
