cask "volta" do
  version "2.2.1"
  sha256 "7d710aeb6224836af823c2ec158d4e7026715224ce0b8e666acd843ab2f86a80"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}-macos-universal.zip"
  name "Volta"
  desc "Native menu-bar power and battery-health dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.2.1 build. Replace it with the SHA-256 of the
  # final notarized release ZIP before publishing this Cask.
  app "Volta.app"
end
