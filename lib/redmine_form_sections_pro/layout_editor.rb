# Copyright (C) 2026 Julien Maisonnas

require 'yaml'

module RedmineFormSectionsPro
  class LayoutEditor

    def self.build_yaml(yaml_text:, tracker_id:, sections:)

      # Lire et valider la configuration existante.
      config = RedmineFormSections::LayoutProvider.parse_config!(
        yaml_text
      )

      # Vérifier l'identifiant du tracker.
      id = Integer(tracker_id)

      unless id.positive?
        raise ArgumentError
      end

      # Modifier uniquement la configuration du tracker concerné.
      if sections == []

        # Sans disposition personnalisée, le tracker doit
        # conserver le formulaire natif de Redmine.
        config['trackers'].delete(id)

      else

        config['trackers'][id] = sections

      end

      # Reconstruire le YAML.
      new_yaml = YAML.dump(config)

      # Valider la configuration complète avant de la retourner.
      RedmineFormSections::LayoutProvider.parse_config!(
        new_yaml
      )

      new_yaml

    rescue ArgumentError, TypeError

      raise RedmineFormSections::LayoutProvider::InvalidConfiguration.new(
        :error_rfs_yaml_invalid_tracker,
        tracker_id: tracker_id.inspect
      )

    end

  end
end