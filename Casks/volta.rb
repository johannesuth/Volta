cask "volta" do
  version "2.1.5"
  sha256 "9b4718cf72f10c93ee063ec2fac0874b54d42f76c71aab62f75e23f889eb7b9b"

  url "https://github.com/johannesuth/volta/releases/download/v#{version}/Volta-#{version}-macos-universal.zip"
  name "Volta"
  desc "Native menu-bar power and battery-health dashboard"
  homepage "https://github.com/johannesuth/volta"

  depends_on macos: ">= :sequoia"

  # The checksum matches the local ad-hoc 2.1.5 build. Replace it with the SHA-256 of the
  # final notarized release ZIP before publishing this Cask.
  app "Volta.app"
end
