require File.expand_path('../../../../test/test_helper', __dir__)
require 'digest'

class RedmineFormSectionsEditorRoutesTest < Redmine::IntegrationTest
  EDITOR_PATH = '/redmine_form_sections/editor'.freeze

  def test_legacy_editor_routes_and_helpers_are_removed
    routes = Rails.application.routes
    %i[get patch].each do |method|
      assert_raises(ActionController::RoutingError) do
        routes.recognize_path('/redmine_form_sections_pro', method: method)
      end
    end
    assert_not_respond_to routes.url_helpers, :rfs_pro_path
    assert_not_respond_to routes.url_helpers, :rfs_pro_save_path
  end

  def test_editor_routes_require_an_administrator
    log_user('jsmith', 'jsmith')
    original_yaml = Setting.plugin_redmine_form_sections.fetch('layouts_yaml')

    get EDITOR_PATH
    assert_response :forbidden
    patch EDITOR_PATH, params: update_params(Tracker.first!, original_yaml)
    assert_response :forbidden
    assert_equal original_yaml, Setting.plugin_redmine_form_sections.fetch('layouts_yaml')
  end

  def test_editor_menu_forms_and_drag_and_drop_markup_in_both_locales
    log_user('admin', 'admin')
    admin = User.find_by!(login: 'admin')
    tracker = Tracker.first!
    field = IssueCustomField.create!(name: 'Editor route field', field_format: 'string', trackers: [tracker])
    yaml = { 'trackers' => { tracker.id => [{ 'title' => 'Editor test section', 'left' => [field.id] }] } }.to_yaml

    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => yaml }) do
      %w[fr en].each do |locale|
        admin.update_column(:language, locale)
        get EDITOR_PATH, params: { tracker_id: tracker.id }

        assert_response :success
        assert_select "#admin-menu a[href='#{EDITOR_PATH}']", text: 'Form Sections', count: 1
        assert_select "form[action='#{EDITOR_PATH}'] select#tracker_id", count: 1
        assert_select 'label[for="tracker_id"]',
                      text: I18n.t(:label_rfs_editor_tracker_configuration, locale: locale)
        assert_select 'form#rfs-editor-titles-form[action=?]', rfs_editor_save_path(tracker_id: tracker.id) do
          assert_select 'input[name="_method"][value="patch"]', count: 1
          assert_select 'input.rfs-editor-save-button[value=?]', I18n.t(:button_rfs_editor_save, locale: locale)
          assert_select '[data-rfs-column="left"] .rfs-editor-field[data-field-id=?]', field.id.to_s, count: 1
        end
        assert_select '[data-rfs-pool="true"]', count: 1
        assert_includes response.body, "editor.addEventListener('dragstart'"
        assert_includes response.body, "editor.addEventListener('drop'"

        get '/settings/plugin/redmine_form_sections'
        assert_response :success
        assert_select "a[href='#{EDITOR_PATH}']", text: I18n.t(:label_rfs_open_visual_editor, locale: locale), count: 1
      end
    end
  end

  def test_editor_update_preserves_reauthentication
    Redmine::SudoMode.stubs(:enabled?).returns(true)
    log_user('admin', 'admin')
    tracker = Tracker.first!
    original_yaml = "trackers: {}\n"

    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => original_yaml }) do
      travel(Redmine::SudoMode.timeout + 1.minute) do
        params = update_params(tracker, original_yaml)
        patch EDITOR_PATH, params: params

        assert_response :success
        assert_select 'form#sudo-form input[name="sudo_password"]', count: 1
        assert_equal original_yaml, Setting.plugin_redmine_form_sections.fetch('layouts_yaml')

        patch EDITOR_PATH, params: params.merge(sudo_password: 'admin')

        assert_redirected_to rfs_editor_path(tracker_id: tracker.id)
        saved = RedmineFormSections::LayoutProvider.parse_config!(Setting.plugin_redmine_form_sections.fetch('layouts_yaml'))
        assert_equal JSON.parse(params[:sections_json]), saved.fetch('trackers').fetch(tracker.id)
      end
    end
  end

  private

  def update_params(tracker, yaml)
    {
      tracker_id: tracker.id,
      yaml_fingerprint: Digest::SHA256.hexdigest(yaml),
      sections_json: [{ title: 'Updated', left: [1] }].to_json
    }
  end
end
