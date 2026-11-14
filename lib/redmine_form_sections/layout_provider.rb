require 'yaml'

module RedmineFormSections
  class LayoutProvider

    class InvalidConfiguration < StandardError; end

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
      parse_config!(yaml_text)
    rescue InvalidConfiguration
      nil
    end

    def self.parse_config!(yaml_text)
      unless yaml_text.is_a?(String)
        raise InvalidConfiguration, 'La configuration YAML doit être du texte.'
      end

      if yaml_text.strip.empty?
        raise InvalidConfiguration, 'La configuration YAML est vide.'
      end

      begin
        config = YAML.safe_load(yaml_text)
      rescue Psych::Exception => e
        raise InvalidConfiguration, "Syntaxe YAML incorrecte : #{e.message}"
      end

      unless config.is_a?(Hash) && config['trackers'].is_a?(Hash)
        raise InvalidConfiguration, 'La configuration doit contenir une clé "trackers".'
      end

      config['trackers'].each do |tracker_id, sections|

        unless tracker_id.is_a?(Integer) && tracker_id.positive?
          raise InvalidConfiguration, "Identifiant de tracker incorrect : #{tracker_id.inspect}"
        end

        unless sections.is_a?(Array)
          raise InvalidConfiguration, "Le tracker #{tracker_id} doit contenir une liste de sections."
        end

        sections.each_with_index do |section, index|

          unless section.is_a?(Hash) &&
                section['title'].is_a?(String) &&
                !section['title'].strip.empty?

            raise InvalidConfiguration,
                  "La section #{index + 1} du tracker #{tracker_id} doit avoir un titre."
          end

          # La colonne gauche est toujours obligatoire.
          unless section.key?('left')
            raise InvalidConfiguration,
                  "Tracker #{tracker_id}, section « #{section['title']} » : " \
                  "la colonne left est obligatoire."
          end

          # La présence de right détermine si la section possède deux colonnes.
          columns = section.key?('right') ? %w[left right] : %w[left]

          columns.each do |column|
            fields = section[column]

            unless fields.is_a?(Array) &&
                  fields.all? { |id| id.is_a?(Integer) && id.positive? }

              raise InvalidConfiguration,
                    "Tracker #{tracker_id}, section « #{section['title']} » : " \
                    "la colonne #{column} doit contenir une liste d'identifiants positifs."
            end
          end

          # Une section sans aucun champ configuré n'a pas d'utilité.
          if columns.all? { |column| section[column].empty? }
            raise InvalidConfiguration,
                  "Tracker #{tracker_id}, section « #{section['title']} » : " \
                  "la section doit contenir au moins un champ."
          end
        end

        # Rassembler les champs de toutes les sections du tracker.
        field_ids = sections.flat_map do |section|
          section['left'] + (section['right'] || [])
        end

        # Rechercher un identifiant présent plusieurs fois.
        grouped_ids = field_ids.group_by(&:itself)

        duplicate_id = grouped_ids.find do |_id, occurrences|
          occurrences.length > 1
        end&.first

        if duplicate_id
          raise InvalidConfiguration,
                "Tracker #{tracker_id} : le champ #{duplicate_id} est déclaré plusieurs fois."
        end
      end

      config
    end
  end
end