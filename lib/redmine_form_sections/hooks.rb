module RedmineFormSections
  class Hooks < Redmine::Hook::ViewListener

    render_on :view_issues_form_details_bottom,
              partial: 'redmine_form_sections/form_marker'

    def view_issues_show_details_bottom(context = {})
      render_issue_show_marker(context, 'rfs-issue-show-details')
    end

    def view_issues_show_description_bottom(context = {})
      render_issue_show_marker(context, 'rfs-issue-show-description-bottom')
    end

    private

    def render_issue_show_marker(context, id)
      issue = context[:issue]
      return unless issue&.project&.module_enabled?('redmine_form_sections')
      return if LayoutProvider.for_issue(issue).blank?

      context.fetch(:hook_caller).tag.template(id: id)
    end

  end
end
