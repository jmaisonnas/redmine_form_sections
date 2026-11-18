get 'redmine_form_sections/export',
    to: 'redmine_form_sections_settings#export',
    as: :rfs_export

# Éditeur graphique des sections.
get 'redmine_form_sections_pro',
    to: 'redmine_form_sections_pro#index',
    as: :rfs_pro

patch 'redmine_form_sections_pro',
      to: 'redmine_form_sections_pro#update',
      as: :rfs_pro_save
