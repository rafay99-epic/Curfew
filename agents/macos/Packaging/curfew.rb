cask "curfew" do
  version "2.1.0"
  sha256 "REPLACE_WITH_THE_SHA256_PRINTED_BY_build-app.sh"

  url "https://github.com/rafay99-epic/Curfew/releases/download/v#{version}/Curfew.zip"
  name "Curfew"
  desc "Lets your phone shut down, lock and log in to this Mac on the home Wi-Fi"
  homepage "https://github.com/rafay99-epic/Curfew"

  depends_on macos: ">= :sonoma"

  app "Curfew.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Curfew.app"]
  end

  uninstall quit:      "com.rafay99.curfew",
            script:    {
              executable: "#{appdir}/Curfew.app/Contents/Resources/curfew",
              args:       ["uninstall"],
              sudo:       true,
            },
            launchctl: "com.rafay99.curfew",
            delete:    [
              "/Library/LaunchDaemons/com.rafay99.curfew.plist",
              "/Library/Application Support/Curfew/bin",
              "/var/run/curfew.sock",
            ]

  zap delete: "/Library/Application Support/Curfew"
end
