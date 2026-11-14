# Copyright (C) 2026 Julien Maisonnas
# SPDX-License-Identifier: GPL-2.0-or-later

Redmine::Plugin.register :redmine_form_sections do
  name 'Redmine Form Sections'
  author 'Julien'
  description 'Personnalisation de la présentation des formulaires Redmine'
  version '0.1.0'

  # Module activable individuellement sur chaque projet.
  project_module :redmine_form_sections do
    permission :use_redmine_form_sections, {}, public: true
  end
  
  settings default: {
    'layouts_yaml' => File.read(
      File.join(__dir__, 'config', 'form_layouts.yml')
    )
  }, partial: 'settings/redmine_form_sections'
end

require_relative 'lib/redmine_form_sections/hooks'
require_relative 'lib/redmine_form_sections/layout_provider'
require_relative 'lib/redmine_form_sections/settings_controller_patch'

unless SettingsController.included_modules.include?(
  RedmineFormSections::SettingsControllerPatch
)
  SettingsController.include(
    RedmineFormSections::SettingsControllerPatch
  )
end