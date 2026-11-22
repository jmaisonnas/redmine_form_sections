get 'redmine_form_sections/export',
    to: 'redmine_form_sections_settings#export',
    as: :rfs_export

# Éditeur graphique des sections.
get 'redmine_form_sections/editor',
    to: 'redmine_form_sections_editor#index',
    as: :rfs_editor

patch 'redmine_form_sections/editor',
      to: 'redmine_form_sections_editor#update',
      as: :rfs_editor_save
