module RedmineFormSections
  class Hooks < Redmine::Hook::ViewListener

    render_on :view_issues_form_details_bottom,
              partial: 'redmine_form_sections/form_marker'

    def view_issues_show_details_bottom(context = {})
      sections = issue_show_sections(context)
      return if sections.blank?

      view = context.fetch(:hook_caller)
      view.tag.template(id: 'rfs-issue-show-details', data: { sections: sections.to_json,
                                                            other_fields: view.l(:label_rfs_other_fields) })
    end

    def view_issues_show_description_bottom(context = {})
      return if issue_show_sections(context).blank?

      view = context.fetch(:hook_caller)
      view.render(partial: 'redmine_form_sections/issue_show_sections')
    end

    private

    def issue_show_sections(context)
      issue = context[:issue]
      return unless issue&.project&.module_enabled?('redmine_form_sections')

      LayoutProvider.for_issue(issue)
    end

  end
end
