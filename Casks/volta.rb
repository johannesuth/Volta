cask "volta" do
  version "2.3.3"
  sha256 "69f2507c1217012a3e13f55d08ed288bf154e6e566c73a74387c719f6d80b8fb"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}.dmg"
  name "Volta"
  desc "Menu-bar battery, battery-health and energy-use dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.3.3 build. Replace it with the SHA-256 that
  # Scripts/sign-notarize.sh prints for the notarized disk image before publishing this Cask.
  app "Volta.app"

  zap trash: "~/Library/Application Support/Volta"
end
