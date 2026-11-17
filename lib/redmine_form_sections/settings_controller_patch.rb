module RedmineFormSections
  module SettingsControllerPatch

    def self.included(base)
      base.before_action :rfs_validate_plugin_settings, only: :plugin
    end

    private

    def rfs_validate_plugin_settings
      # Ne concerne que l'enregistrement des paramètres de notre plugin.
      return unless request.post? &&
                    params[:id].to_s == 'redmine_form_sections'

      settings = params[:settings]&.permit!.to_h || {}

      # Déclenche une exception si le YAML est incorrect.
      RedmineFormSections::LayoutProvider.parse_config!(
        settings['layouts_yaml']
      )

    rescue RedmineFormSections::LayoutProvider::InvalidConfiguration => e
      # Reconstituer les variables attendues par la vue native Redmine.
      @plugin = Redmine::Plugin.find(:redmine_form_sections)
      @partial = @plugin.settings[:partial]
      @settings = settings

      # Afficher l'erreur et conserver le YAML saisi.
      flash.now[:error] = I18n.t(
        e.translation_key,
        **e.interpolation
      )

      # Interrompre l'enregistrement.
      render 'settings/plugin', status: :unprocessable_entity
    end
  end
end