require "test_helper"

# Unbounded and Figtree are served by the app itself: no page asks a third
# party for anything, so no visitor's IP reaches Google (no trackers).
class SelfHostedFontsTest < ActionDispatch::IntegrationTest
  FONT_FILES = %w[
    unbounded-latin-600-normal.woff2 unbounded-latin-700-normal.woff2 unbounded-latin-800-normal.woff2
    figtree-latin-400-normal.woff2 figtree-latin-500-normal.woff2
    figtree-latin-600-normal.woff2 figtree-latin-700-normal.woff2
  ].freeze

  test "pages load no font from Google" do
    get new_user_session_path

    assert_response :success
    assert_no_match(/fonts\.googleapis|fonts\.gstatic/, response.body)
  end

  test "the font files and their licences ship with the app" do
    fonts = Rails.root.join("app/assets/fonts")
    FONT_FILES.each do |file|
      assert fonts.join(file).exist?, file
      assert Rails.application.assets.load_path.find(file), "#{file} is not an asset"
    end
    assert fonts.join("OFL-Unbounded.txt").read.include?("SIL Open Font License")
    assert fonts.join("OFL-Figtree.txt").read.include?("SIL Open Font License")
  end

  test "the stylesheet declares every font face it uses" do
    css = Rails.root.join("app/assets/tailwind/application.css").read

    FONT_FILES.each { |file| assert_includes css, %(url("#{file}")) }
    assert_no_match(%r{https?://}, css.scan(/@font-face\s*\{[^}]*\}/).join)
  end
end
