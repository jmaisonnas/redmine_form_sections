# Copyright (C) 2026 Julien Maisonnas
# SPDX-License-Identifier: GPL-2.0-or-later

Redmine::Plugin.register :redmine_form_sections do
  name 'Redmine Form Sections'
  author 'Julien Maisonnas'
  description 'Organize Redmine custom fields into configurable form sections'
  version '1.0.0'
  url 'https://github.com/jmaisonnas/redmine_form_sections'
  author_url 'https://github.com/jmaisonnas'

  # Module activable individuellement sur chaque projet.
  project_module :redmine_form_sections do
    permission :use_redmine_form_sections, {}, public: true
  end

  # Accès à l'éditeur graphique depuis le menu Administration.
  menu :admin_menu,
       :redmine_form_sections_pro,
       { controller: 'redmine_form_sections_pro', action: 'index' },
       caption: :label_rfs_pro_admin,
       icon: 'custom-fields',
       html: { class: 'icon icon-custom-fields' }

  settings default: {
    'layouts_yaml' => "trackers: {}\n"
  }, partial: 'settings/redmine_form_sections'
end

require_relative 'lib/redmine_form_sections/hooks'
require_relative 'lib/redmine_form_sections/layout_provider'
require_relative 'lib/redmine_form_sections_pro/layout_editor'
require_relative 'lib/redmine_form_sections/settings_controller_patch'

unless SettingsController.included_modules.include?(
  RedmineFormSections::SettingsControllerPatch
)
  SettingsController.include(
    RedmineFormSections::SettingsControllerPatch
  )
end
