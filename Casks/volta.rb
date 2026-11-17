cask "volta" do
  version "2.1.4"
  sha256 "834d53a390d09b43577711b082997b70d0731bf808c8e6926c59ffc24841e452"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}-macos-universal.zip"
  name "Volta"
  desc "Native menu-bar power and battery-health dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.1.4 build. Replace it with the SHA-256 of the
  # final notarized release ZIP before publishing this Cask.
  app "Volta.app"
end
