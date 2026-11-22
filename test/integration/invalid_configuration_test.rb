require File.expand_path('../../../../test/test_helper', __dir__)
require 'digest'

class RedmineFormSectionsInvalidConfigurationTest < Redmine::IntegrationTest

  def test_invalid_saved_yaml_warns_the_admin_and_blocks_visual_edits
    issue = Issue.find(1)
    invalid_yaml = 'trackers: ['
    log_user('admin', 'admin')

    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => invalid_yaml }) do
      get rfs_editor_path
      assert_response :success
      assert_select '.rfs-editor-invalid-yaml-warning[role="alert"]', count: 1

      get rfs_editor_path(tracker_id: issue.tracker_id)
      assert_response :success
      assert_select '.rfs-editor-invalid-yaml-warning[role="alert"]', count: 1
      assert_select '#rfs-editor-section-list fieldset', count: 0

      patch rfs_editor_save_path(tracker_id: issue.tracker_id),
            params: { yaml_fingerprint: Digest::SHA256.hexdigest(invalid_yaml),
                      sections_json: [{ title: 'Replacement', left: [1] }].to_json }
      assert_redirected_to rfs_editor_path(tracker_id: issue.tracker_id)
      assert flash[:error].present?
      assert_equal invalid_yaml, Setting.plugin_redmine_form_sections['layouts_yaml']
    end
  end

  def test_visual_editor_rejects_an_invalid_section_without_overwriting_saved_yaml
    tracker = Tracker.first!
    yaml = { 'trackers' => { tracker.id => [{ 'title' => 'Existing', 'left' => [1] }] } }.to_yaml
    log_user('admin', 'admin')

    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => yaml }) do
      patch rfs_editor_save_path(tracker_id: tracker.id),
            params: { yaml_fingerprint: Digest::SHA256.hexdigest(yaml),
                      sections_json: [{ title: 'Empty section', left: [] }].to_json }

      assert_redirected_to rfs_editor_path(tracker_id: tracker.id)
      assert_equal I18n.t(:error_rfs_yaml_empty_section, tracker_id: tracker.id, title: 'Empty section'), flash[:error]
      assert_equal yaml, Setting.plugin_redmine_form_sections['layouts_yaml']
    end
  end

end
