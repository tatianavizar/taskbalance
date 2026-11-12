# Librairie de composants : chaque helper rend un partial de
# app/views/components/. Les composants prennent des valeurs simples en
# paramètre et ne contiennent aucune logique métier.
module ComponentsHelper
  MEMBER_COLORS = %w[mint blue stone sky sage sand].freeze

  def logo(size: 28)
    render "components/logo", size: size
  end

  # Bouton retour de 44 px. Masqué dans les coquilles natives (la barre native
  # fournit déjà le retour).
  def back_button(path, label: t("common.back"))
    return if hotwire_native_app?

    render "components/back_button", path: path, label: label
  end

  # `unread` : nombre de notifications non lues ; nil masque la cloche.
  def app_header(name, unread: nil)
    render "components/app_header", name: name, unread: unread
  end

  def tab_bar(active: active_tab)
    render "components/tab_bar", active: active
  end

  def card(href: nil, **options, &block)
    render layout: "components/card", locals: { href: href, options: options }, &block
  end

  # Ligne de liste avec chevron. `leading` : un avatar déjà rendu, par exemple.
  def list_row(title:, subtitle: nil, href: nil, leading: nil, trailing: nil, **options)
    render "components/list_row", title: title, subtitle: subtitle, href: href,
           leading: leading, trailing: trailing, options: options
  end

  def callout(&block)
    render layout: "components/callout", &block
  end

  # Monogramme dans la couleur du membre. `pending: true` : invitation en
  # attente, contour en pointillés.
  def avatar(initials:, color: "mint", pending: false, size: 30)
    color = "mint" unless MEMBER_COLORS.include?(color.to_s)
    render "components/avatar", initials: initials, color: color, pending: pending, size: size
  end

  # tone : :soft, :ink (alerte), :outline (en attente).
  def status_pill(text, tone: :soft)
    render "components/status_pill", text: text, tone: tone
  end

  def sticky_cta(&block)
    render layout: "components/sticky_cta", &block
  end

  # Balance d'une charge.
  #   share      : part de la personne qui regarde, en %
  #   others     : [{ name:, share: }] les autres membres
  #   fair       : repère de la part juste (par défaut 100 / nombre de membres)
  #   balanced   : semaine équilibrée -> la part passe en vert foncé
  def balance(title:, count:, name:, share:, others:, balanced: false, fair: nil, aria: nil)
    members = others.size + 1
    fair ||= (100.0 / members).round
    aria ||= t("components.balance.aria", title: title, you: name, share: share,
               others: others.map { |o| "#{o[:name]} #{o[:share]} %" }.to_sentence, fair: fair)
    render "components/balance", title: title, count: count, name: name, share: share,
           others: others, balanced: balanced, fair: fair, aria: aria
  end

  def level_progress(level:, done:, total:, href: nil)
    render "components/level_progress", level: level, done: done, total: total, href: href
  end

  # Points de progression de l'intro. `current` va de 1 à `total`.
  def progress_dots(current:, total:)
    render "components/progress_dots", current: current, total: total
  end

  # Avancement de la mise en place (B1) : une barre segmentée et les noms des
  # étapes. `steps` : tableau de libellés, `current` : numéro de l'étape (de 1).
  def step_progress(steps:, current:)
    render "components/step_progress", steps: steps, current: current
  end

  def confirm_dialog
    render "components/confirm_dialog"
  end
end
