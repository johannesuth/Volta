cask "volta" do
  version "2.5.1"
  sha256 "e3f2e22750bb66d29ae7a0769eb70394e2470e1efeb4da8bad11617a4d07b1b2"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}.dmg"
  name "Volta"
  desc "Menu-bar battery, battery-health and energy-use dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.5.1 build. Replace it with the SHA-256 that
  # Scripts/sign-notarize.sh prints for the notarized disk image before publishing this Cask.
  app "Volta.app"

  zap trash: "~/Library/Application Support/Volta"
end
