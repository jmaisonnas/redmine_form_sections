require 'yaml'

module RedmineFormSections
  class LayoutProvider

    class InvalidConfiguration < StandardError
      attr_reader :translation_key, :interpolation

      def initialize(translation_key, **interpolation)
        @translation_key = translation_key
        @interpolation = interpolation

        super(translation_key.to_s)
      end
    end

    def self.for_issue(issue)
      yaml_text = Setting.plugin_redmine_form_sections['layouts_yaml']
      parse_config(yaml_text)&.dig('trackers', issue.tracker_id.to_i)
    end

    def self.parse_config(yaml_text)
      parse_config!(yaml_text)
    rescue InvalidConfiguration
      nil
    end

    def self.parse_config!(yaml_text)
      unless yaml_text.is_a?(String)
        raise InvalidConfiguration.new(:error_rfs_yaml_not_text)
      end

      if yaml_text.strip.empty?
        raise InvalidConfiguration.new(:error_rfs_yaml_empty)
      end

      begin
        config = YAML.safe_load(yaml_text)
      rescue Psych::Exception => e
        raise InvalidConfiguration.new(
          :error_rfs_yaml_syntax,
          details: e.message
        )
      end

      unless config.is_a?(Hash) && config['trackers'].is_a?(Hash)
        raise InvalidConfiguration.new(:error_rfs_yaml_missing_trackers)
      end

      config['trackers'].each do |tracker_id, sections|

        unless tracker_id.is_a?(Integer) && tracker_id.positive?
          raise InvalidConfiguration.new(
            :error_rfs_yaml_invalid_tracker,
            tracker_id: tracker_id.inspect
          )
        end

        unless sections.is_a?(Array)
          raise InvalidConfiguration.new(
            :error_rfs_yaml_invalid_sections,
            tracker_id: tracker_id
          )
        end

        sections.each_with_index do |section, index|

          unless section.is_a?(Hash) &&
                 section['title'].is_a?(String) &&
                 !section['title'].strip.empty?

            raise InvalidConfiguration.new(
              :error_rfs_yaml_missing_title,
              tracker_id: tracker_id,
              index: index + 1
            )
          end

          # Refuser les propriétés inconnues dans une section.
          allowed_keys = %w[title left right]
          unknown_keys = section.keys - allowed_keys

          unless unknown_keys.empty?
            raise InvalidConfiguration.new(
              :error_rfs_yaml_unknown_section_key,
              tracker_id: tracker_id,
              title: section['title'],
              key: unknown_keys.first.to_s
            )
          end

          # La colonne gauche est toujours obligatoire.
          unless section.key?('left')
            raise InvalidConfiguration.new(
              :error_rfs_yaml_left_required,
              tracker_id: tracker_id,
              title: section['title']
            )
          end

          # La présence de right détermine le nombre de colonnes.
          columns = section.key?('right') ? %w[left right] : %w[left]

          columns.each do |column|
            fields = section[column]

            unless fields.is_a?(Array) &&
                   fields.all? { |id| id.is_a?(Integer) && id.positive? }

              raise InvalidConfiguration.new(
                :error_rfs_yaml_invalid_column,
                tracker_id: tracker_id,
                title: section['title'],
                column: column
              )
            end
          end

          # Ne pas accepter une section sans aucun champ configuré.
          if columns.all? { |column| section[column].empty? }
            raise InvalidConfiguration.new(
              :error_rfs_yaml_empty_section,
              tracker_id: tracker_id,
              title: section['title']
            )
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
          raise InvalidConfiguration.new(
            :error_rfs_yaml_duplicate_field,
            tracker_id: tracker_id,
            field_id: duplicate_id
          )
        end
      end

      config
    end
  end
end
