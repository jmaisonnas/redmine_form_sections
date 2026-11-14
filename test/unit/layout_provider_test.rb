require 'minitest/autorun'
require_relative '../../lib/redmine_form_sections/layout_provider'

class LayoutProviderTest < Minitest::Test

  # Simule une demande Redmine avec son identifiant de tracker
  FakeIssue = Struct.new(:tracker_id)

  def test_tracker_anomalie_has_two_sections
    issue = FakeIssue.new(1)

    sections = RedmineFormSections::LayoutProvider.for_issue(issue)

    assert_equal 2, sections.size

    assert_equal 'Application', sections[0]['title']
    assert_equal [1], sections[0]['left']
    assert_equal [2], sections[0]['right']

    assert_equal 'Client', sections[1]['title']
  end

  def test_unconfigured_tracker_returns_nil
    issue = FakeIssue.new(2)

    sections = RedmineFormSections::LayoutProvider.for_issue(issue)

    assert_nil sections
  end

end