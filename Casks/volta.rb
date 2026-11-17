cask "volta" do
  version "2.4.1"
  sha256 "851236249ed7008c0c5862227619d59b2490ceca261fed0cceb073953196ffba"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}.dmg"
  name "Volta"
  desc "Menu-bar battery, battery-health and energy-use dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.4.1 build. Replace it with the SHA-256 that
  # Scripts/sign-notarize.sh prints for the notarized disk image before publishing this Cask.
  app "Volta.app"

  zap trash: "~/Library/Application Support/Volta"
end
