require 'yaml'

module RedmineFormSections
  class LayoutProvider

    CONFIG_PATH = File.expand_path(
      '../../config/form_layouts.yml',
      __dir__
    )

    def self.for_issue(issue)
      config = YAML.safe_load_file(CONFIG_PATH) || {}

      layouts_by_tracker = config.fetch('trackers', {})

      layouts_by_tracker[issue.tracker_id.to_i]
    end

  end
end