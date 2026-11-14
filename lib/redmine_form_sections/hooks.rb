module RedmineFormSections
  class Hooks < Redmine::Hook::ViewListener

    render_on :view_issues_form_details_bottom,
              partial: 'redmine_form_sections/form_marker'

  end
end