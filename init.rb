Redmine::Plugin.register :redmine_form_sections do
  name 'Redmine Form Sections'
  author 'Julien'
  description 'Personnalisation de la présentation des formulaires Redmine'
  version '0.1.0'

  # Module activable individuellement sur chaque projet.
  project_module :redmine_form_sections do
    permission :use_redmine_form_sections, {}, public: true
  end
end

require_relative 'lib/redmine_form_sections/hooks'
require_relative 'lib/redmine_form_sections/layout_provider'