require "test_helper"

# Colour contrast of the design tokens (docs/design-system.md), read from the
# Tailwind theme itself so a changed token is checked, not a copy of it.
# WCAG 2.2: 4.5:1 for text, 3:1 for large text and for graphics a person
# needs to read (bars, zone, focus ring).
#
# The app has two grounds: the light one (tokens on `--color-bg`) and the ink
# one (intro I2, alerts, primary buttons, cookie banner). Both are checked.
class ContrastTest < ActiveSupport::TestCase
  # The tokens moved to tokens.css (shared with the back-office build).
  CSS = Rails.root.join("app/assets/tailwind/application.css").read + Rails.root.join("app/assets/tailwind/tokens.css").read

  def token(name)
    CSS[/--color-#{Regexp.escape(name)}:\s*(#[0-9a-fA-F]{6})/, 1] or flunk("token --color-#{name} not found")
  end

  def luminance(hex)
    rgb = hex.delete("#").scan(/../).map { |c| c.hex / 255.0 }
    r, g, b = rgb.map { |v| v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def ratio(a, b)
    hi, lo = [ luminance(a), luminance(b) ].max, [ luminance(a), luminance(b) ].min
    ((hi + 0.05) / (lo + 0.05)).round(2)
  end

  def assert_contrast(fg, bg, minimum, label)
    fg_hex = fg.start_with?("#") ? fg : token(fg)
    bg_hex = bg.start_with?("#") ? bg : token(bg)
    actual = ratio(fg_hex, bg_hex)
    assert_operator actual, :>=, minimum, "#{label}: #{fg_hex} on #{bg_hex} is #{actual}:1, needs #{minimum}:1"
  end

  # ---- light ground: text --------------------------------------------------------

  test "text on the light grounds is at least 4.5:1" do
    %w[bg surface mint soft soft-2].each do |ground|
      assert_contrast "ink", ground, 4.5, "ink on #{ground}"
    end
    %w[bg surface soft soft-2 mint].each do |ground|
      assert_contrast "muted", ground, 4.5, "secondary text on #{ground}"
    end
    assert_contrast "balanced", "bg", 4.5, "balanced figures on the ground"
    assert_contrast "balanced", "surface", 4.5, "balanced figures on a card"
    assert_contrast "self", "surface", 3.0, "your share figure (22 px bold, large text) on a card"
  end

  test "the member colours carry ink letters at 4.5:1" do
    %w[mint blue stone sky sage sand].each do |color|
      assert_contrast "ink", "member-#{color}", 4.5, "monogram on #{color}"
    end
  end

  test "buttons and alerts: mint on ink, white on ink, ink on mint" do
    assert_contrast "mint", "ink", 4.5, "primary button"
    assert_contrast "#ffffff", "ink", 4.5, "alert text"
    assert_contrast "ink", "mint", 4.5, "button on the ink ground"
  end

  # ---- ink ground (intro I2, cookie banner) ---------------------------------------------

  test "text on the ink ground: the intro cards and the banner" do
    assert_contrast "#c3d9cc", "#18261f", 4.5, "intro level captions on the ink card"
    assert_contrast "mint", "#18261f", 4.5, "intro zone label"
    assert_contrast "mint", "ink", 4.5, "banner link on ink"
  end

  test "the Ult. badge no longer puts white on terracotta (finding 26)" do
    assert_operator ratio("#ffffff", token("self")), :<, 4.5, "white on terracotta stays a failing pair, which is why the badge changed"
    badge = Rails.root.join("app/views/intro/_step2.html.erb").read
    assert_no_match(/color-self/, badge, "terracotta only marks the viewer's own share")
    assert_contrast "ink", "#ffffff", 4.5, "Ult. badge: ink on white"
  end

  # ---- graphics ---------------------------------------------------------------------------

  test "bars, the fair-share marker and the focus ring are at least 3:1 against what they sit on" do
    assert_contrast "self", "track", 3.0, "your bar on the track"
    assert_contrast "others", "track", 3.0, "others' bars on the track"
    assert_contrast "balanced", "track", 3.0, "balanced bar on the track"
    assert_contrast "ink", "track", 3.0, "fair-share marker on the track"
    assert_contrast "ink", "bg", 3.0, "focus ring on the ground"
    assert_contrast "ink", "surface", 3.0, "focus ring on a card"
    assert_contrast "ink", "mint", 3.0, "focus ring on mint"
    assert_contrast "ink", "soft", 3.0, "focus ring on a soft ground"
  end

  test "field borders are 3:1 on their ground only where they carry meaning: the invalid state uses the ink border" do
    assert_contrast "ink", "surface", 3.0, "invalid field border"
  end
end
