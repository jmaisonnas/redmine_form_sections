class RedmineFormSectionsSettingsController < ApplicationController
  before_action :require_admin

  def export
    # Récupérer le YAML enregistré dans Redmine.
    yaml_text = Setting.plugin_redmine_form_sections['layouts_yaml']

    # Transmettre le contenu au navigateur sous forme de fichier.
    send_data(
      yaml_text.to_s,
      filename: "redmine-form-sections-#{Date.current}.yml",
      type: 'application/x-yaml; charset=utf-8',
      disposition: 'attachment'
    )
  end
end