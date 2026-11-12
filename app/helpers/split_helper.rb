# Wording of the split screens (C4 to C16, B10 to B14). Percentages only,
# never « points » (decision 2026-11-08).
module SplitHelper
  # A share for display: rounded, « — » when nothing is planned on it.
  def share_percent(value)
    value.nil? ? "—" : "#{value.round} %"
  end

  # « chaque jour », « 2 fois par semaine », « chaque mois », « une fois ».
  def frequency_label(frequency, times_per_period = 1)
    frequency = frequency.to_s
    times = times_per_period.to_i
    if Recurrence::REPEATING.include?(frequency) && times > 1
      t("split.frequency.times.#{frequency}", count: times)
    else
      t("split.frequency.#{frequency}")
    end
  end

  # « Mentale », « Exécution », « Mentale et exécution ».
  def loads_label(mental, execution)
    key = if mental && execution then :both elsif mental then :mental else :execution end
    t("split.loads.#{key}")
  end

  # Two states only (decision 2026-11-08): « Validée par tous les deux » /
  # « Validée par tous », or « En attente de <prénom> ».
  def validation_status(plan)
    return t("split.status.awaiting_proposal", names: plan.pending_participants.map(&:first_name).to_sentence) if plan.awaiting_proposal?

    pending = plan.pending_participants
    if pending.empty?
      plan.participants.size == 2 ? t("split.status.validated_two") : t("split.status.validated_all")
    else
      t("split.status.waiting", names: pending.map(&:first_name).to_sentence)
    end
  end

  # D6: « Tout le foyer » is only a label, shown when everyone carries it.
  def assignees_label(keys, participants)
    if participants.size > 1 && (participants.map(&:key) - keys).empty?
      t("split.everyone")
    else
      participants.select { |p| keys.include?(p.key) }.map(&:first_name).to_sentence
    end
  end

  # « 50/50 » for two people, « parts égales » beyond.
  def even_split_label(participants)
    participants.size == 2 ? "50/50" : t("split.even_shares")
  end
end
