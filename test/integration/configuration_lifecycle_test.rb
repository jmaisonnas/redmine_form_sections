require File.expand_path('../../../../test/test_helper', __dir__)
require 'digest'

class RedmineFormSectionsConfigurationLifecycleTest < Redmine::IntegrationTest
  SETTINGS_PATH = '/settings/plugin/redmine_form_sections'.freeze
  EMPTY_YAML = "trackers: {}\n".freeze

  def setup
    super
    @issue = Issue.find(1)
    @project = @issue.project
    @project.enable_module!(:redmine_form_sections)
    @field = IssueCustomField.create!(name: 'Layout lifecycle field', field_format: 'string',
                                      is_for_all: true, visible: true, trackers: @project.trackers)
    log_user('admin', 'admin')
  end

  def test_fresh_installation_has_no_layout
    Setting.where(name: 'plugin_redmine_form_sections').delete_all
    Setting.clear_cache

    assert_equal EMPTY_YAML, saved_yaml
    assert_empty_admin_views
    assert_ticket_layout(nil)
    assert_not Setting.exists?(name: 'plugin_redmine_form_sections')
  ensure
    Setting.clear_cache
  end

  def test_advanced_settings_can_reset_and_recreate_a_layout
    initial = sections('Existing layout')
    replacement = sections('New layout')

    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => layout_yaml(initial) }) do
      assert_ticket_layout(initial)

      save_advanced(EMPTY_YAML)
      assert_equal EMPTY_YAML, saved_yaml
      assert_empty_admin_views
      assert_ticket_layout(nil)

      save_advanced(layout_yaml(replacement))
      assert_visual_sections(replacement)
      assert_ticket_layout(replacement)
    end
  end

  def test_visual_editor_can_remove_the_last_tracker_layout_and_create_another
    initial = sections('Existing layout')
    replacement = sections('New layout')
    other_tracker = @project.trackers.where.not(id: @issue.tracker_id).first!
    other_sections = sections('Other tracker')
    yaml = { 'trackers' => { @issue.tracker_id => initial, other_tracker.id => other_sections } }.to_yaml

    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => yaml }) do
      assert_visual_sections(initial)
      assert_ticket_layout(initial)

      save_visual(@issue.tracker_id, [])
      assert_equal({ 'trackers' => { other_tracker.id => other_sections } }, YAML.safe_load(saved_yaml))
      assert_visual_sections([])
      assert_ticket_layout(nil)

      save_visual(other_tracker.id, [])
      assert_equal({ 'trackers' => {} }, YAML.safe_load(saved_yaml))
      assert_empty_admin_views
      assert_ticket_layout(nil)

      save_visual(@issue.tracker_id, replacement)
      assert_visual_sections(replacement)
      assert_advanced_yaml(layout_yaml(replacement))
      assert_ticket_layout(replacement)
    end
  end

  def test_invalid_saved_configuration_leaves_all_ticket_views_native
    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => 'trackers: [' }) do
      assert_ticket_layout(nil)
    end
  end

  private

  def saved_yaml
    Setting.plugin_redmine_form_sections.fetch('layouts_yaml')
  end

  def sections(title)
    [{ 'title' => title, 'left' => [@field.id] }]
  end

  def layout_yaml(sections)
    { 'trackers' => { @issue.tracker_id => sections } }.to_yaml
  end

  def save_advanced(yaml)
    post SETTINGS_PATH, params: { settings: { layouts_yaml: yaml } }
    assert_redirected_to SETTINGS_PATH
  end

  def save_visual(tracker_id, sections)
    patch rfs_editor_save_path(tracker_id: tracker_id),
          params: { yaml_fingerprint: Digest::SHA256.hexdigest(saved_yaml), sections_json: sections.to_json }
    assert_redirected_to rfs_editor_path(tracker_id: tracker_id)
    assert_nil flash[:error]
  end

  def assert_empty_admin_views
    assert_advanced_yaml(saved_yaml)
    assert_visual_sections([])
    assert_select '#rfs-editor-no-layout', count: 1
  end

  def assert_advanced_yaml(yaml)
    get SETTINGS_PATH
    assert_response :success
    assert_select 'textarea[name="settings[layouts_yaml]"]', text: yaml
  end

  def assert_visual_sections(sections)
    get rfs_editor_path(tracker_id: @issue.tracker_id)
    assert_response :success
    assert_select '.rfs-editor-invalid-yaml-warning', count: 0
    assert_select '#rfs-editor-section-list fieldset', count: sections.length
    assert_select '#rfs-editor-sections-json', count: 1 do |inputs|
      assert_equal sections, JSON.parse(inputs.first['value'])
    end
  end

  def assert_ticket_layout(sections)
    get new_project_issue_path(@project), params: { issue: { tracker_id: @issue.tracker_id } }
    assert_form_layout(sections)

    get edit_issue_path(@issue)
    assert_form_layout(sections)

    get issue_path(@issue)
    assert_response :success
    assert_select ".issue.details .attribute.cf_#{@field.id}", count: 1
    if sections
      assert_select '#rfs-issue-show-details', count: 1 do |markers|
        assert_equal sections, JSON.parse(markers.first['data-sections'])
      end
    else
      assert_select '#rfs-issue-show-details, #rfs-issue-show-description-bottom', count: 0
      assert_select '.rfs-show-filter', count: 0
    end
  end

  def assert_form_layout(sections)
    assert_response :success
    assert_select "#attributes input#issue_custom_field_values_#{@field.id}", count: 1
    assert_select '#rfs-sections', count: 1 do |markers|
      assert_equal sections.to_json, markers.first['data-sections']
    end
  end
end
