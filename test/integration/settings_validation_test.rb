require File.expand_path('../../../../test/test_helper', __dir__)

class RedmineFormSectionsSettingsTest < Redmine::IntegrationTest

  def test_invalid_yaml_is_rejected_without_overwriting_settings
    # Se connecter comme administrateur
    log_user('admin', 'admin')

    # Mémoriser la configuration actuelle
    original_yaml = Setting.plugin_redmine_form_sections['layouts_yaml']

    # Soumettre une configuration YAML invalide
    post '/settings/plugin/redmine_form_sections',
         params: {
           settings: {
             layouts_yaml: 'trackers: ['
           }
         }

    # Redmine doit refuser la requête
    assert_response :unprocessable_entity

    # La configuration existante doit être préservée
    assert_equal original_yaml,
                 Setting.plugin_redmine_form_sections['layouts_yaml']

    # Le YAML incorrect doit rester dans la zone de saisie
    assert_select 'textarea[name="settings[layouts_yaml]"]',
                  text: 'trackers: ['
  end

  def test_valid_yaml_is_saved
    # Se connecter comme administrateur
    log_user('admin', 'admin')

    # Préparer une configuration valide
    valid_yaml = <<~YAML
      trackers:
        1:
          - title: "Application"
            left: [1]
            right: [2]
    YAML

    # Envoyer la configuration à Redmine
    post '/settings/plugin/redmine_form_sections',
         params: {
           settings: {
             layouts_yaml: valid_yaml
           }
         }

    # Redmine doit accepter l'enregistrement
    assert_redirected_to '/settings/plugin/redmine_form_sections'

    # Vérifier la valeur enregistrée
    assert_equal valid_yaml,
                 Setting.plugin_redmine_form_sections['layouts_yaml']

    # Revenir sur la page de configuration
    get '/settings/plugin/redmine_form_sections'

    assert_response :success

    # Vérifier que l'éditeur affiche la configuration enregistrée
    assert_select 'textarea[name="settings[layouts_yaml]"]',
                  text: valid_yaml
  end  

  def test_non_admin_cannot_modify_settings
    # Se connecter comme utilisateur non administrateur
    log_user('jsmith', 'jsmith')

    # Mémoriser la configuration actuelle
    original_yaml = Setting.plugin_redmine_form_sections['layouts_yaml']

    # Préparer une configuration valide
    valid_yaml = <<~YAML
      trackers:
        1:
          - title: "Modification interdite"
            left: [1]
    YAML

    # Tenter de modifier la configuration
    post '/settings/plugin/redmine_form_sections',
         params: {
           settings: {
             layouts_yaml: valid_yaml
           }
         }

    # Redmine doit refuser l'accès
    assert_response :forbidden

    # La configuration ne doit pas avoir changé
    assert_equal original_yaml,
                 Setting.plugin_redmine_form_sections['layouts_yaml']
  end

end