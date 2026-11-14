require 'yaml'

module RedmineFormSections
  class LayoutProvider

    CONFIG_PATH = File.expand_path(
      '../../config/form_layouts.yml',
      __dir__
    )

    def self.for_issue(issue)
      # Configuration enregistrée dans Redmine
      settings_yaml = nil

      if defined?(Setting)
        settings_yaml = Setting.plugin_redmine_form_sections['layouts_yaml']
      end

      # Utiliser la configuration Redmine si elle est valide,
      # sinon revenir au fichier de configuration initial
      config = parse_config(settings_yaml)

      config ||= parse_config(File.read(CONFIG_PATH))

      # Aucune configuration exploitable
      return nil unless config

      # Rechercher la configuration du tracker
      config.dig('trackers', issue.tracker_id.to_i)
    end

    def self.parse_config(yaml_text)
      return nil unless yaml_text.is_a?(String)
      return nil if yaml_text.strip.empty?

      config = YAML.safe_load(yaml_text)

      return nil unless config.is_a?(Hash)

      trackers = config['trackers']

      return nil unless trackers.is_a?(Hash)

      valid = trackers.all? do |tracker_id, sections|

        tracker_id.is_a?(Integer) &&
          tracker_id.positive? &&
          sections.is_a?(Array) &&
          sections.all? do |section|

            section.is_a?(Hash) &&
              section['title'].is_a?(String) &&
              !section['title'].strip.empty? &&
              %w[left right].all? do |column|

                section[column].is_a?(Array) &&
                  section[column].all? do |field_id|
                    field_id.is_a?(Integer) && field_id.positive?
                  end
              end
          end
      end

      valid ? config : nil

    rescue Psych::Exception
      nil
    end

  end
end