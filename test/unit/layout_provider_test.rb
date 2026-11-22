require 'minitest/autorun'
require_relative '../../lib/redmine_form_sections/layout_provider'

class LayoutProviderTest < Minitest::Test

  def test_empty_configuration_is_valid
    assert_equal({ 'trackers' => {} }, RedmineFormSections::LayoutProvider.parse_config!("trackers: {}\n"))
  end

  def test_invalid_yaml_returns_nil
    invalid_yaml = "trackers:\n  1: ["
  
    config = RedmineFormSections::LayoutProvider.parse_config(invalid_yaml)
  
    assert_nil config
  end

  def test_invalid_structure_returns_nil
    invalid_yaml = <<~YAML
      trackers:
        1:
          - title: "Client"
            left: "incorrect"
            right: [3]
    YAML

    config = RedmineFormSections::LayoutProvider.parse_config(invalid_yaml)

    assert_nil config
  end

  def test_duplicate_field_in_same_tracker_is_rejected
    yaml = <<~YAML
      trackers:
        1:
          - title: Application
            left: [1, 2]
            right: [3]

          - title: Client
            left: [4]
            right: [1]
    YAML

    error = assert_raises(
      RedmineFormSections::LayoutProvider::InvalidConfiguration
    ) do
      RedmineFormSections::LayoutProvider.parse_config!(yaml)
    end

    assert_equal :error_rfs_yaml_duplicate_field, error.translation_key
    assert_equal 1, error.interpolation[:tracker_id]
    assert_equal 1, error.interpolation[:field_id]
  end

  def test_same_field_can_be_used_by_different_trackers
    yaml = <<~YAML
      trackers:
        1:
          - title: Application
            left: [1]

        2:
          - title: Assistance
            left: [1]
    YAML

    config = RedmineFormSections::LayoutProvider.parse_config!(yaml)

    assert_equal [1], config['trackers'][1][0]['left']
    assert_equal [1], config['trackers'][2][0]['left']
  end

  def test_rejects_unknown_section_property
    yaml = <<~YAML
      trackers:
        1:
          - title: "Application"
            left: [1]
            rigth: [2]
    YAML

    error = assert_raises(
      RedmineFormSections::LayoutProvider::InvalidConfiguration
    ) do
      RedmineFormSections::LayoutProvider.parse_config!(yaml)
    end

    assert_equal(
      :error_rfs_yaml_unknown_section_key,
      error.translation_key
    )

    assert_equal 'rigth', error.interpolation[:key]
  end

end
