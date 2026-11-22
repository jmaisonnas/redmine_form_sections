require 'digest'

class RedmineFormSectionsProController < ApplicationController
  layout 'admin'

  before_action :require_admin
  require_sudo_mode :update

  def index
    @trackers = Tracker.order(:position, :id)
    yaml_text = Setting.plugin_redmine_form_sections['layouts_yaml']
    config = RedmineFormSections::LayoutProvider.parse_config(yaml_text)
    @invalid_saved_yaml = config.nil?

    # Rechercher le tracker sélectionné.
    @tracker = @trackers.find do |tracker|
      tracker.id.to_s == params[:tracker_id].to_s
    end

    return unless @tracker

    # Champs personnalisés associés au tracker sélectionné.
    @available_fields = @tracker.custom_fields.order(:position, :id)

    # Identifier la version de la configuration actuellement affichée.
    @yaml_fingerprint = Digest::SHA256.hexdigest(yaml_text.to_s)

    @sections = config&.dig('trackers', @tracker.id) || []

    # Identifiants des champs déclarés dans les sections.
    configured_ids = @sections.flat_map do |section|
      section['left'] + (section['right'] || [])
    end.uniq

    # Champs associés au tracker mais absents des sections.
    @unclassified_fields = @available_fields.reject do |field|
      configured_ids.include?(field.id)
    end

    # Retrouver les champs configurés qui existent dans Redmine.
    configured_fields = IssueCustomField
      .where(id: configured_ids)
      .index_by(&:id)

    # Réunir les champs configurés et les champs disponibles.
    available_fields_by_id = @available_fields.index_by(&:id)

    @fields_by_id = configured_fields.merge(available_fields_by_id)

    # Identifier les champs associés au tracker.
    @available_field_ids = available_fields_by_id.keys

    # Identifier les champs configurés en pleine largeur.
    @full_width_field_ids = configured_fields.values
      .select(&:full_width_layout?)
      .map(&:id)
  end

  def update
    # Vérifier que le tracker existe.
    tracker = Tracker.find_by(id: params[:tracker_id])
    return render_404 unless tracker

    # Récupérer les paramètres actuels du plugin.
    settings = Setting.plugin_redmine_form_sections.deep_dup
    yaml_text = settings['layouts_yaml']

    # Vérifier que la configuration n'a pas changé
    # depuis son chargement dans l'éditeur.
    current_fingerprint = Digest::SHA256.hexdigest(yaml_text.to_s)

    if params[:yaml_fingerprint].to_s != current_fingerprint
      flash[:error] = l(:error_rfs_pro_configuration_changed)

      return redirect_to rfs_pro_path(tracker_id: tracker.id)
    end

    # Récupérer la disposition complète transmise par l'éditeur.
    sections = JSON.parse(params[:sections_json].to_s)

    unless sections.is_a?(Array)
      flash[:error] = l(:error_rfs_pro_invalid_layout)

      return redirect_to rfs_pro_path(tracker_id: tracker.id)
    end

    # Construire et valider le nouveau YAML.
    new_yaml = RedmineFormSectionsPro::LayoutEditor.build_yaml(
      yaml_text: yaml_text,
      tracker_id: tracker.id,
      sections: sections
    )

    # Enregistrer uniquement le YAML du plugin.
    settings['layouts_yaml'] = new_yaml

    Setting.plugin_redmine_form_sections = settings

    flash[:notice] = l(:notice_successful_update)

    redirect_to rfs_pro_path(tracker_id: tracker.id)

  rescue JSON::ParserError

    flash[:error] = l(:error_rfs_pro_invalid_data)

    redirect_to rfs_pro_path(tracker_id: params[:tracker_id])

  rescue RedmineFormSections::LayoutProvider::InvalidConfiguration => e

    flash[:error] = I18n.t(
      e.translation_key,
      **e.interpolation
    )

    redirect_to rfs_pro_path(tracker_id: params[:tracker_id])
  end

end
