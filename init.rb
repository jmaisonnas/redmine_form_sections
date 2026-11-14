Redmine::Plugin.register :redmine_form_sections do
  name 'Redmine Form Sections'
  author 'Julien'
  description 'Personnalisation de la présentation des formulaires Redmine'
  version '0.1.0'
end

require_relative 'lib/redmine_form_sections/hooks'