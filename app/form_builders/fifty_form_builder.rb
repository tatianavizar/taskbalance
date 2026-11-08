# Form builder maison (remplace simple_form). Rendu fidèle à la maquette A3 :
# label au-dessus, indication, erreur en ligne avec aria-invalid et
# aria-describedby, résumé d'erreurs sombre, bouton principal en pilule.
class FiftyFormBuilder < ActionView::Helpers::FormBuilder
  # Champ texte, email, mot de passe, nombre, date…
  #   f.field :email, as: :email, hint: "…", label: "Email"
  def field(method, as: :text, label: nil, hint: nil, **html)
    html[:class] = [ "field-input", html[:class] ].compact.join(" ")
    wrap(method, label: label, hint: hint, html: html) do |attrs|
      public_send(INPUT_TYPES.fetch(as), method, **attrs)
    end
  end

  # Liste déroulante. choices : tableau [libellé, valeur] ou options_for_select.
  def select_field(method, choices, label: nil, hint: nil, options: {}, **html)
    html[:class] = [ "field-input select-input", html[:class] ].compact.join(" ")
    wrap(method, label: label, hint: hint, html: html) do |attrs|
      select(method, choices, options, attrs)
    end
  end

  # Case à cocher en ligne (A4) : « Garder la session ouverte ».
  def checkbox_field(method, label: nil, hint: nil, **html)
    described_by = hint ? field_id(method, :hint) : nil
    body = @template.label(object_name, method, class: "flex items-start gap-3 min-h-[44px] py-2 cursor-pointer") do
      @template.safe_join([
        check_box(method, { class: "check-input", "aria-describedby": described_by, **html }),
        @template.tag.span(check_icon, class: "check-box"),
        @template.tag.span(label || object_label(method), class: "pt-px")
      ])
    end
    @template.safe_join([ body, hint_tag(method, hint) ].compact)
  end

  # Interrupteur : une case à cocher avec role="switch".
  def switch_field(method, label: nil, hint: nil, **html)
    described_by = hint ? field_id(method, :hint) : nil
    body = @template.label(object_name, method, class: "flex items-center justify-between gap-3 min-h-[44px] py-2 cursor-pointer") do
      @template.safe_join([
        @template.tag.span(label || object_label(method), class: "font-semibold"),
        check_box(method, { class: "switch-input", role: "switch", "aria-describedby": described_by, **html })
      ])
    end
    @template.safe_join([ body, hint_tag(method, hint) ].compact)
  end

  # Contrôle segmenté : des boutons radio côte à côte.
  #   f.segmented :frequency, [["Jour", "daily"], ["Semaine", "weekly"]], label: "Fréquence"
  def segmented(method, choices, label: nil, hint: nil)
    described_by = [ (field_id(method, :hint) if hint), (field_id(method, :error) if errors?(method)) ].compact.join(" ").presence
    radios = choices.map do |text, value|
      @template.safe_join([
        radio_button(method, value, class: "segment-input"),
        label(method, text, value: value, class: "segment-label")
      ])
    end
    @template.tag.fieldset(class: "min-w-0", "aria-describedby": described_by) do
      @template.safe_join([
        @template.tag.legend(label || object_label(method), class: "field-label"),
        @template.tag.div(@template.safe_join(radios), class: "segments"),
        hint_tag(method, hint),
        error_tag(method)
      ].compact)
    end
  end

  # Résumé sombre en tête de formulaire : « 1 champ à corriger ».
  def error_summary
    return if object.nil? || object.errors.none?

    fields = object.errors.attribute_names - [ :base ]
    parts = []
    parts << @template.t("forms.error_summary", count: fields.size).html_safe if fields.any?
    parts.concat(object.errors[:base].map { |message| ERB::Util.html_escape(message) })
    @template.tag.div(
      @template.safe_join(parts, @template.tag.br),
      class: "alert-box", role: "alert", id: field_id(:error_summary)
    )
  end

  # Bouton principal. f.submit "Texte", variant: :secondary pour un autre poids.
  def submit(value = nil, variant: :primary, **html)
    html[:class] = [ "btn btn-#{variant}", html[:class] ].compact.join(" ")
    html[:data] = { disable_with: false }.merge(html[:data] || {})
    super(value, html)
  end

  private

  INPUT_TYPES = {
    text: :text_field, email: :email_field, password: :password_field,
    number: :number_field, date: :date_field, tel: :telephone_field,
    textarea: :text_area, search: :search_field
  }.freeze

  def wrap(method, label:, hint:, html:)
    invalid = errors?(method)
    described_by = [ (field_id(method, :hint) if hint), (field_id(method, :error) if invalid) ].compact.join(" ").presence
    attrs = html.merge(
      "aria-invalid": (invalid ? "true" : nil),
      "aria-describedby": described_by
    ).compact

    @template.tag.div do
      @template.safe_join([
        self.label(method, label || object_label(method), class: "field-label"),
        yield(attrs),
        hint_tag(method, hint),
        error_tag(method)
      ].compact)
    end
  end

  def errors?(method)
    object.respond_to?(:errors) && object.errors[method].any?
  end

  def hint_tag(method, hint)
    return unless hint

    @template.tag.div(hint, class: "field-hint", id: field_id(method, :hint))
  end

  def error_tag(method)
    return unless errors?(method)

    @template.tag.div(class: "field-error", id: field_id(method, :error)) do
      @template.safe_join([
        @template.tag.span("!", class: "field-error-icon", "aria-hidden": "true"),
        @template.tag.span(object.errors[method].first)
      ])
    end
  end

  def object_label(method)
    object.class.respond_to?(:human_attribute_name) ? object.class.human_attribute_name(method) : method.to_s.humanize
  end

  def check_icon
    @template.raw('<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>')
  end
end
