require File.expand_path('../../../../test/test_helper', __dir__)

class RedmineFormSectionsExportTest < Redmine::IntegrationTest

  def test_admin_can_export_configuration
    # Se connecter comme administrateur
    log_user('admin', 'admin')

    # Récupérer la configuration attendue
    expected_yaml = Setting.plugin_redmine_form_sections['layouts_yaml'].to_s

    # Demander l'export
    get '/redmine_form_sections/export'

    # Le téléchargement doit être autorisé
    assert_response :success

    # Le contenu doit correspondre à la configuration enregistrée
    assert_equal expected_yaml, response.body

    # Vérifier le type de fichier
    assert_equal 'application/x-yaml', response.media_type

    # Vérifier que le navigateur recevra un fichier à télécharger
    assert_includes response.headers['Content-Disposition'], 'attachment'
  end

  def test_non_admin_cannot_export_configuration
    # Se connecter comme utilisateur non administrateur
    log_user('jsmith', 'jsmith')

    # Tenter de télécharger la configuration
    get '/redmine_form_sections/export'

    # Redmine doit refuser l'accès
    assert_response :forbidden
  end

end