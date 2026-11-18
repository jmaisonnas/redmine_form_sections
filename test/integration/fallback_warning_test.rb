require File.expand_path('../../../../test/test_helper', __dir__)

class RedmineFormSectionsProFallbackWarningTest < Redmine::IntegrationTest

  def setup
    super
    @original_settings = Setting.plugin_redmine_form_sections.deep_dup
    log_user('admin', 'admin')
  end

  def teardown
    Setting.plugin_redmine_form_sections = @original_settings
    super
  end

  def test_invalid_yaml_displays_warning
    settings = @original_settings.deep_dup
    settings['layouts_yaml'] = 'trackers: ['

    Setting.plugin_redmine_form_sections = settings

    get rfs_pro_path(tracker_id: Tracker.first.id)

    assert_response :success
    assert_select '.rfs-pro-fallback-warning', count: 1
  end

  def test_valid_yaml_does_not_display_warning
    settings = @original_settings.deep_dup
    settings['layouts_yaml'] = "trackers: {}\n"

    Setting.plugin_redmine_form_sections = settings

    get rfs_pro_path(tracker_id: Tracker.first.id)

    assert_response :success
    assert_select '.rfs-pro-fallback-warning', count: 0
  end

end