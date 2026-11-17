cask "volta" do
  version "2.2.0"
  sha256 "20cb1918401c7c4217f52ec270c3e72816f0132d9752b4b3a3adb638e838cc78"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}-macos-universal.zip"
  name "Volta"
  desc "Native menu-bar power and battery-health dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.2.0 build. Replace it with the SHA-256 of the
  # final notarized release ZIP before publishing this Cask.
  app "Volta.app"
end
