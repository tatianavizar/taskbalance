require "test_helper"
require_relative "previews/notification_mailer_preview"

class NotificationMailerTest < ActionMailer::TestCase
  # Every method of the preview must render, in HTML and text, with the
  # unsubscribe headers and no leftover "translation missing".
  NotificationMailerPreview.instance_methods(false).each do |preview|
    test "preview #{preview} renders" do
      mail = NotificationMailerPreview.new.public_send(preview)

      assert_equal [ "virginie.martin@example.com" ], mail.to
      assert mail.subject.present?
      [ mail.html_part.body.to_s, mail.text_part.body.to_s, mail.subject ].each do |body|
        assert_no_match(/translation missing|%\{/, body)
      end
      assert_match(%r{/desinscription/}, mail.header["List-Unsubscribe"].to_s)
    end
  end

  test "List-Unsubscribe and List-Unsubscribe-Post carry a working one-click link" do
    mail = NotificationMailerPreview.new.weekly_report_unbalanced
    url = mail.header["List-Unsubscribe"].to_s[/<(.+)>/, 1]

    assert_equal "List-Unsubscribe=One-Click", mail.header["List-Unsubscribe-Post"].to_s
    assert_match(%r{\Ahttp://example.com/desinscription/[\w\-=]+\z}, url)
    assert_includes mail.html_part.body.to_s, url
    assert_includes mail.text_part.body.to_s, url
  end

  test "the report email follows H3: figures, the last weeks and the link to the report" do
    mail = NotificationMailerPreview.new.weekly_report_unbalanced
    text = mail.text_part.body.to_s

    assert_equal "Semaine 45 : Virginie 72 %, Karim 28 % de la charge mentale", mail.subject
    assert_includes text, "Vous portez 72 % de la charge mentale."
    assert_includes text, "Bilan provisoire. Au-dessus de 60 % : la semaine n'est pas équilibrée, comme les 2 précédentes."
    assert_includes text, "Le foyer reste au niveau 1, à 2 semaines équilibrées du niveau 2."
    assert_includes text, "Charge mentale : Virginie 18 · Karim 7"
    assert_includes text, "Temps : Virginie 10 h 00 · Karim 5 h 10"
    assert_includes text, "S42 54 % · S43 63 % · S44 66 % · S45 72 %"
    assert_includes text, "Voir le bilan complet : http://example.com/bilan"
  end

  test "no email says « points au-dessus » or uses a point médian" do
    NotificationMailerPreview.instance_methods(false).each do |preview|
      mail = NotificationMailerPreview.new.public_send(preview)
      body = [ mail.subject, mail.text_part.body.to_s ].join("\n")

      assert_no_match(/points? au-dessus|points? en dessous/i, body)
      assert_no_match(/\w·\w/, body)
    end
  end
end
