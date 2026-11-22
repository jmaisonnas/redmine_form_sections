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

    attachment = Attachment.first!
    attachment.update_columns(container_type: 'Issue', container_id: @issue.id)
    sections = [{ 'title' => %q{Quotes "' & </script><b id="rfs-test-title">Title</b>},
                  'left' => [ordinary.id], 'right' => [full_width.id] }]

    with_layout(sections) do
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
      assert_select '#rfs-issue-show-details', count: 1 do |markers|
        assert_equal sections, JSON.parse(markers.first['data-sections'])
        assert_equal I18n.t(:label_rfs_other_fields), markers.first['data-other-fields']
      end
      assert_select '#rfs-test-title, .rfs-show-sections', count: 0
      assert_select 'div.issue.details > .description ~ .attachments a', text: attachment.filename
      assert_select 'template#rfs-issue-show-description-bottom > label.rfs-show-filter',
                    text: I18n.t(:label_rfs_hide_empty_fields), count: 1 do
        assert_select 'input[type="checkbox"][autocomplete="off"]:not([checked])', count: 1
      end
      assert_includes response.body, 'arrangeIssueShowFields(document);'
    end
  end

  def test_native_values_are_kept_in_the_initial_response_for_the_filter
    empty = add_custom_field('Empty ordinary field', '0', value: '')
    zero = add_custom_field('Zero field', '0', value: '0', field_format: 'int')
    negative = add_custom_field('Negative field', '0', value: '0', field_format: 'bool')
    image = add_custom_field('Rich image field', '1', value: '![](https://example.test/image.png)',
                             field_format: 'text', text_formatting: 'full')
    sections = [{ 'title' => 'Filter values', 'left' => [empty.id, zero.id, negative.id, image.id] }]

    with_settings(text_formatting: 'common_mark') do
      with_layout(sections) do
        get issue_path(@issue)

        assert_response :success
        assert_select ".attribute.cf_#{empty.id} > .value", text: '', count: 1
        assert_select ".attribute.cf_#{zero.id} > .value", text: '0', count: 1
        assert_select ".attribute.cf_#{negative.id} > .value", text: I18n.t(:general_text_No), count: 1
        assert_select ".attribute.cf_#{image.id} > .value .wiki img[src='https://example.test/image.png']", count: 1
        assert_select '.rfs-hidden-by-filter', count: 0
      end
    end
  end

  def test_only_rendered_full_width_fields_are_available_to_the_script
    full_width = add_custom_field('Full-width field', '1')
    empty = add_custom_field('Empty full-width field', '1', value: '')
    @issue.tracker.custom_fields = [empty, full_width]

    with_layout([{ 'title' => 'Section', 'left' => [empty.id, full_width.id] }]) do
      get issue_path(@issue)

      assert_response :success
      assert_select '.issue.details > .attributes .attribute[class*=" cf_"]', count: 0
      assert_select "div.issue.details > .attribute.cf_#{full_width.id} + " \
                    'template#rfs-issue-show-description-bottom', count: 1
      assert_select ".attribute.cf_#{empty.id}", count: 0
    end
  end

  def test_restricted_field_labels_and_values_are_only_sent_to_authorized_readers
    project = @issue.project
    reader = User.find_by!(login: 'jsmith')
    reader_role = Role.create!(name: 'RFS visibility reader', permissions: [:view_issues], issues_visibility: 'all')
    permitted_role = Role.create!(name: 'RFS field access', permissions: [:view_issues])
    member = project.members.find_by(user: reader) || project.members.build(user: reader)
    member.roles = [reader_role]
    member.save!

    restricted = %w[0 1].to_h do |width|
      value = "RFS_RESTRICTED_VALUE_#{width}"
      field = add_custom_field("RFS_RESTRICTED_LABEL_#{width}", width, value: value, roles: [permitted_role])
      [field, value]
    end
    public_field = add_custom_field('Public visibility test field', '0')
    sections = [
      { 'title' => 'Restricted section', 'left' => restricted.keys.map(&:id) },
      { 'title' => 'Public section', 'left' => [public_field.id] }
    ]

    with_layout(sections) do
      get issue_path(@issue)

      assert_response :success
      restricted.each do |field, value|
        assert_select ".issue.details .attribute.cf_#{field.id}", count: 1
        assert_includes response.body, field.name
        assert_includes response.body, value
      end

      reset!
      log_user('jsmith', 'jsmith')
      get issue_path(@issue)

      assert_response :success
      assert_select '#rfs-issue-show-details', count: 1
      assert_select ".issue.details .attribute.cf_#{public_field.id}", count: 1
      restricted.each do |field, value|
        assert_select ".attribute.cf_#{field.id}", count: 0
        assert_not_includes response.body, field.name
        assert_not_includes response.body, value
      end
    end
  end

  def test_no_markers_when_module_is_disabled
    @issue.project.disable_module!(:redmine_form_sections)

    with_layout([{ 'title' => 'Section', 'left' => [1] }]) do
      assert_no_markers_on_issue
    end
  end

  def test_no_markers_when_tracker_is_missing_or_has_no_sections
    with_settings(plugin_redmine_form_sections: { 'layouts_yaml' => 'trackers: {}' }) do
      assert_no_markers_on_issue
    end

    with_layout([]) { assert_no_markers_on_issue }
  end

  private

  def with_layout(sections, &block)
    config = { 'trackers' => { @issue.tracker_id => sections } }
    with_settings({ plugin_redmine_form_sections: { 'layouts_yaml' => config.to_yaml } }, &block)
  end

  def add_custom_field(name, full_width_layout, value: name, roles: [], field_format: 'string', **options)
    field = IssueCustomField.create!(name: name, field_format: field_format, is_for_all: true,
                                     visible: roles.empty?, roles: roles, trackers: [@issue.tracker],
                                     full_width_layout: full_width_layout, **options)
    CustomValue.create!(customized: @issue, custom_field: field, value: value)
    field
  end

  def assert_no_markers_on_issue
    get issue_path(@issue)

    assert_response :success
    assert_select MARKERS, count: 0
    assert_select 'label.rfs-show-filter', count: 0
    assert_not_includes response.body, 'arrangeIssueShowFields(document);'
  end
end
