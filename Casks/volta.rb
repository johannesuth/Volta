cask "volta" do
  version "2.4.2"
  sha256 "47a9b72163cbbd8e8c8d07d59d9133296bbce47f52aa5c84f97e8bcbbf2d65fe"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}.dmg"
  name "Volta"
  desc "Menu-bar battery, battery-health and energy-use dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.4.2 build. Replace it with the SHA-256 that
  # Scripts/sign-notarize.sh prints for the notarized disk image before publishing this Cask.
  app "Volta.app"

  zap trash: "~/Library/Application Support/Volta"
end
