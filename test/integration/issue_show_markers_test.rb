require File.expand_path('../../../../test/test_helper', __dir__)

class RedmineFormSectionsIssueShowMarkersTest < Redmine::IntegrationTest
  MARKERS = '#rfs-issue-show-details, #rfs-issue-show-description-bottom'.freeze

  def setup
    super
    @issue = Issue.find(1)
    @issue.project.enable_module!(:redmine_form_sections)
    log_user('admin', 'admin')
  end

  def test_markers_follow_the_native_custom_field_blocks
    ordinary = add_custom_field('Ordinary field', '0')
    full_width = add_custom_field('Full-width field', '1')
    @issue.update_column(:description, 'Description de contrôle')

    with_layout([{ 'title' => 'Section', 'left' => [ordinary.id, full_width.id] }]) do
      get issue_path(@issue)

      assert_response :success
      assert_select 'div.issue.details > div.attributes' do
        assert_select ".splitcontent .attribute.cf_#{ordinary.id}", count: 1
        assert_select '.splitcontent + template#rfs-issue-show-details', count: 1
      end
      assert_select "div.issue.details > .description ~ .attribute.cf_#{full_width.id} + " \
                    'template#rfs-issue-show-description-bottom', count: 1
      assert_select ".attribute.cf_#{full_width.id}", count: 1
      assert_select MARKERS, count: 2
    end
  end

  def test_no_markers_when_module_is_disabled
    @issue.project.disable_module!(:redmine_form_sections)

    with_layout([{ 'title' => 'Section', 'left' => [1] }]) do
      assert_no_markers_on_issue
    end
  end

  def test_no_markers_when_tracker_is_missing_or_has_no_sections
    with_settings('plugin_redmine_form_sections' => { 'layouts_yaml' => 'trackers: {}' }) do
      assert_no_markers_on_issue
    end

    with_layout([]) { assert_no_markers_on_issue }
  end

  private

  def with_layout(sections, &block)
    config = { 'trackers' => { @issue.tracker_id => sections } }
    with_settings('plugin_redmine_form_sections' => { 'layouts_yaml' => config.to_yaml }, &block)
  end

  def add_custom_field(name, full_width_layout)
    field = IssueCustomField.create!(name: name, field_format: 'string', is_for_all: true,
                                     visible: true, trackers: [@issue.tracker],
                                     full_width_layout: full_width_layout)
    CustomValue.create!(customized: @issue, custom_field: field, value: name)
    field
  end

  def assert_no_markers_on_issue
    get issue_path(@issue)

    assert_response :success
    assert_select MARKERS, count: 0
  end
end
