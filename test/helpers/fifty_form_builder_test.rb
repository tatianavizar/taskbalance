require "test_helper"

class FiftyFormBuilderTest < ActionView::TestCase
  def render_form(user)
    form_with(model: user, url: "/users", builder: FiftyFormBuilder) do |f|
      concat f.error_summary
      concat f.field(:email, as: :email, hint: "Une indication")
      concat f.submit("Créer")
    end
  end

  test "a valid field has a label, a hint and no error markup" do
    html = render_form(User.new(email: "a@b.fr"))

    assert_includes html, 'for="user_email"'
    assert_includes html, 'class="field-hint"'
    assert_not_includes html, "aria-invalid"
    assert_not_includes html, "alert-box"
  end

  test "an invalid field is flagged and linked to its inline error" do
    user = User.new(email: "")
    user.valid?
    html = render_form(user)

    assert_includes html, 'aria-invalid="true"'
    assert_match(/aria-describedby="user_email_hint user_email_error"/, html)
    assert_includes html, 'id="user_email_error"'
    assert_not_includes html, "alert-box", "field errors are shown inline only, no summary banner"
  end

  test "an error on the form itself is shown in the summary" do
    user = User.new(email: "a@b.fr")
    user.errors.add(:base, "Ce lien a expiré.")
    html = render_form(user)

    assert_includes html, "Ce lien a expiré."
    assert_includes html, 'role="alert"'
  end

  test "a password field gets an eye button, hidden by default" do
    html = fields_for(:user, User.new, builder: FiftyFormBuilder) do |f|
      concat f.field(:password, as: :password)
    end

    assert_includes html, 'data-controller="password-visibility"'
    assert_includes html, 'type="password"'
    assert_includes html, 'type="button"'
    assert_includes html, 'aria-label="Afficher le mot de passe"'
    assert_includes html, 'aria-pressed="false"'
    assert_includes html, 'aria-controls="user_password"'
  end

  test "other fields have no eye button" do
    assert_not_includes render_form(User.new), "password-visibility"
  end

  test "submit renders the primary button" do
    assert_includes render_form(User.new), "btn btn-primary"
  end

  test "checkbox, switch and segmented controls are accessible" do
    html = fields_for(:demo, Struct.new(:a, :b, :c).new(true, false, "x"), builder: FiftyFormBuilder) do |f|
      concat f.checkbox_field(:a, label: "Garder la session ouverte")
      concat f.switch_field(:b, label: "Notifications")
      concat f.segmented(:c, [ [ "Un", "x" ], [ "Deux", "y" ] ], label: "Choix")
    end

    assert_includes html, "Garder la session ouverte"
    assert_includes html, 'role="switch"'
    assert_includes html, "<fieldset"
    assert_includes html, 'type="radio"'
  end
end
