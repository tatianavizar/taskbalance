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
  #   share      : part de la personne qui regarde, en % (nil : rien de mesuré)
  #   others     : [{ name:, share:, balanced: }] les autres membres
  #   fair       : repère de la part juste (par défaut 100 / nombre de membres)
  #   zone       : zone équilibrée (Range, par défaut la part juste +/- 10)
  #   balanced   : true -> la part passe en vert foncé ; false -> « hors zone »
  #
  # À deux, une barre partagée ; à trois et plus, une barre par membre avec la
  # zone en pointillés. Le texte alternatif commence par le titre, nomme chaque
  # part, la zone et les personnes hors zone : la barre n'est jamais seule.
  def balance(title:, count:, name:, share:, others:, balanced: nil, fair: nil, zone: nil, aria: nil)
    members = others.size + 1
    fair ||= HouseholdRules.fair_share(members)
    zone ||= HouseholdRules.zone(members)
    aria ||= balance_aria(title: title, name: name, share: share, others: others,
                          balanced: balanced, fair: fair, zone: zone)
    render "components/balance", title: title, count: count, name: name, share: share,
           others: others, balanced: balanced, fair: fair, zone: zone, aria: aria
  end

  # `total` nil : niveau ultime, il n'y a plus de niveau suivant.
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

  private

  def balance_aria(title:, name:, share:, others:, balanced:, fair:, zone:)
    return t("components.balance.aria_empty", title: title, fair: fair) if share.nil?

    parts = [ "#{name} #{share} %" ] + others.map { |o| "#{o[:name]} #{o[:share].nil? ? "—" : "#{o[:share]} %"}" }
    text = t("components.balance.aria", title: title, shares: parts.to_sentence, fair: fair)
    text += " #{t("components.balance.aria_zone", min: zone.begin, max: zone.end)}" if zone
    out = (balanced == false ? [ name ] : []) + others.select { |o| o[:balanced] == false && !o[:share].nil? }.map { |o| o[:name] }
    text += " #{t("components.balance.aria_out", names: out.to_sentence)}" if out.any?
    text
  end
end
