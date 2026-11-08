# Le form builder affiche lui-même l'erreur (aria-invalid + message) : on retire
# le <div class="field_with_errors"> que Rails ajoute autour des champs.
ActionView::Base.field_error_proc = proc { |html_tag, _instance| html_tag }
