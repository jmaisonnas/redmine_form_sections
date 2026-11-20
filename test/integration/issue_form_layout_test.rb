require File.expand_path('../../../../test/test_helper', __dir__)

class RedmineFormSectionsIssueFormLayoutTest < Redmine::IntegrationTest
  def setup
    super
    @issue = Issue.find(1)
    @project = @issue.project
    @project.enable_module!(:redmine_form_sections)
    @ordinary = add_custom_field('Ordinary field')
    @wide = add_custom_field('Full-width field', full_width: true)
    @unclassified = add_custom_field('Unclassified field')
    @sections = [
      { 'title' => %q{Quotes "' & </script><b id="rfs-test-title">Title</b>},
        'left' => [@ordinary.id, @wide.id], 'right' => [] },
      { 'title' => 'Field absent from the form', 'left' => [999_999] }
    ]
    log_user('admin', 'admin')
  end

  def test_new_form_keeps_the_configuration_and_native_controls
    with_layout(@issue.tracker_id => @sections) do
      get new_project_issue_path(@project), params: { issue: { tracker_id: @issue.tracker_id } }

      assert_native_form
    end
  end

  def test_edit_form_keeps_the_configuration_and_existing_values
    CustomValue.create!(customized: @issue, custom_field: @ordinary, value: 'Original value')

    with_layout(@issue.tracker_id => @sections) do
      get edit_issue_path(@issue)

      assert_native_form
      assert_select "#issue_custom_field_values_#{@ordinary.id}[value='Original value']", count: 1
    end
  end

  def test_tracker_change_refreshes_the_layout_in_both_forms
    other_tracker = @project.trackers.where.not(id: @issue.tracker_id).first!
    other_sections = [{ 'title' => 'Layout for the new tracker', 'left' => [@ordinary.id] }]
    params = { issue: { tracker_id: other_tracker.id }, form_update_triggered_by: 'issue_tracker_id' }

    with_layout(@issue.tracker_id => @sections, other_tracker.id => other_sections) do
      post new_project_issue_path(@project, format: :js), params: params, xhr: true
      assert_tracker_refresh(other_tracker)

      patch edit_issue_path(@issue, format: :js), params: params, xhr: true
      assert_tracker_refresh(other_tracker)
    end
  end

  def test_form_without_applicable_sections_keeps_native_controls
    [{}, { @issue.tracker_id => [] }].each do |trackers|
      with_layout(trackers) do
        get edit_issue_path(@issue)

        assert_response :success
        assert_select '#rfs-sections', count: 1 do |markers|
          assert_equal trackers[@issue.tracker_id].to_json, markers.first['data-sections']
        end
        assert_select '#rfs-sections .rfs-section', count: 0
        assert_select "#attributes .splitcontent p #issue_custom_field_values_#{@ordinary.id}", count: 1
        assert_select "#attributes > p #issue_custom_field_values_#{@wide.id}", count: 1
      end
    end
  end

  def test_custom_field_values_are_saved_on_creation_and_update
    with_layout(@issue.tracker_id => @sections) do
      assert_difference 'Issue.count' do
        post project_issues_path(@project), params: { issue: {
          tracker_id: @issue.tracker_id, subject: 'Issue for the layout test',
          priority_id: @issue.priority_id,
          custom_field_values: { @ordinary.id.to_s => 'Created', @wide.id.to_s => 'Long value' }
        } }
      end
      issue = Issue.find_by!(subject: 'Issue for the layout test')
      assert_redirected_to issue_path(issue)
      assert_equal 'Created', issue.custom_field_value(@ordinary.id)
      assert_equal 'Long value', issue.custom_field_value(@wide.id)

      patch issue_path(issue), params: { issue: { custom_field_values: { @ordinary.id.to_s => 'Updated' } } }

      assert_redirected_to issue_path(issue)
      assert_equal 'Updated', issue.reload.custom_field_value(@ordinary.id)
      assert_equal 'Long value', issue.custom_field_value(@wide.id)
    end
  end

  private

  def add_custom_field(name, full_width: false)
    IssueCustomField.create!(name: name, field_format: 'string', is_for_all: true,
                             visible: true, trackers: [@issue.tracker],
                             full_width_layout: full_width ? '1' : '0')
  end

  def with_layout(trackers, &block)
    yaml = { 'trackers' => trackers }.to_yaml
    with_settings('plugin_redmine_form_sections' => { 'layouts_yaml' => yaml }, &block)
  end

  def assert_native_form
    assert_response :success
    assert_select '#rfs-sections', count: 1 do |markers|
      assert_equal @sections, JSON.parse(markers.first['data-sections'])
    end
    assert_select '#rfs-test-title', count: 0
    assert_includes response.body, 'function planSections('
    assert_select "#attributes .splitcontent p #issue_custom_field_values_#{@ordinary.id}", count: 1
    assert_select "#attributes > p #issue_custom_field_values_#{@wide.id}", count: 1
    assert_select "#attributes .splitcontent p #issue_custom_field_values_#{@unclassified.id}", count: 1
  end

  def assert_tracker_refresh(tracker)
    assert_response :success
    assert_includes response.body, "data-tracker-id=\\\"#{tracker.id}\\\""
    assert_includes response.body, 'Layout for the new tracker'
    assert_includes response.body, 'function planSections('
    assert_not_includes response.body, 'Field absent from the form'
  end
end
