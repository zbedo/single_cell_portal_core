require "test_helper"

class PrecomputedScoreTest < ActiveSupport::TestCase
  def setup
    @precomputed_score ||= PrecomputedScore.new
  end
end
