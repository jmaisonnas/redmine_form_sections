require File.expand_path('../../../../test/test_helper', __dir__)
require 'digest'

class RedmineFormSectionsProSaveConflictTest < Redmine::IntegrationTest

  def test_stale_fingerprint_rejects_update
    log_user('admin', 'admin')

    tracker = Tracker.first
    original_settings = Setting.plugin_redmine_form_sections.deep_dup

    # Configuration initialement affichée par l'éditeur.
    initial_yaml = {
      'trackers' => {
        tracker.id => [
          { 'title' => 'Version initiale', 'left' => [1] }
        ]
      }
    }.to_yaml

    # Configuration enregistrée entre-temps par un autre administrateur.
    concurrent_yaml = {
      'trackers' => {
        tracker.id => [
          { 'title' => 'Version concurrente', 'left' => [1] }
        ]
      }
    }.to_yaml

    settings = original_settings.deep_dup
    settings['layouts_yaml'] = concurrent_yaml

    Setting.plugin_redmine_form_sections = settings

    # Tentative d'enregistrement depuis l'ancienne version.
    patch rfs_pro_save_path(tracker_id: tracker.id),
          params: {
            yaml_fingerprint: Digest::SHA256.hexdigest(initial_yaml),
            sections_json: [
              { title: 'Modification locale', left: [1] }
            ].to_json
          }

    # L'enregistrement doit être refusé.
    assert_redirected_to rfs_pro_path(tracker_id: tracker.id)

    # La configuration concurrente doit être conservée.
    assert_equal concurrent_yaml,
                 Setting.plugin_redmine_form_sections['layouts_yaml']

    assert_equal(
      I18n.t(:error_rfs_pro_configuration_changed),
      flash[:error]
    )

  ensure
    # Restaurer les paramètres de test.
    if original_settings
      Setting.plugin_redmine_form_sections = original_settings
    end
  end

end