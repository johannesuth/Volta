Copyright © 2026 Johannes Uth. All rights reserved.

# Contributing

Volta is proprietary software; see [LICENSE](LICENSE). No right to use,
modify, redistribute or sublicense the source is granted by publishing this
repository.

Bug reports and feature requests are welcome through GitHub Issues. Please do
not submit pull requests or copied third-party code unless Johannes Uth has
invited the contribution and granted written permission in advance.

## Local checks

Requirements: macOS 15 or later, Xcode, and SwiftPM.

```sh
export DEVELOPER_DIR="$(xcode-select -p)"
swift test
./Scripts/build-app.sh
```

Do not commit signing certificates, notarization credentials, personal battery
logs, or diagnostic files that may contain device identifiers.
