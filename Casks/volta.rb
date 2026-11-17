cask "volta" do
  version "2.3.1"
  sha256 "dfcf30b0dd70e0b66d57bd4b232960e75a440baefd7168061627a85a45a2afb2"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}.dmg"
  name "Volta"
  desc "Menu-bar battery, battery-health and energy-use dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.3.1 build. Replace it with the SHA-256 that
  # Scripts/sign-notarize.sh prints for the notarized disk image before publishing this Cask.
  app "Volta.app"

  zap trash: "~/Library/Application Support/Volta"
end
