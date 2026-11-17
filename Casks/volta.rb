cask "volta" do
  version "2.2.2"
  sha256 "f113d55a546000a3b1600282a16cdcc36a832e1a939e0e2085d0c9bc47f7cdbb"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}-macos-universal.zip"
  name "Volta"
  desc "Native menu-bar power and battery-health dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.2.2 build. Replace it with the SHA-256 of the
  # final notarized release ZIP before publishing this Cask.
  app "Volta.app"
end
