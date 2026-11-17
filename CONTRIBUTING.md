# Contributing

Thanks for your interest in Volta.

Volta is free to use and its source code is public, but it is not open source:
the code is copyrighted and published under the [Volta License](LICENSE). You
may read it and build it for your own use, but you may not copy, publish or
redistribute it.

## How you can help

- **Report a bug or suggest a feature** through
  [GitHub Issues](https://github.com/johannesuth/volta/issues). The issue forms
  ask for everything needed: Volta version, macOS version, Mac model and the
  steps to reproduce.
- **Security problems** go through a private advisory, not a public issue. See
  [SECURITY.md](SECURITY.md).

Pull requests are only accepted when Johannes Uth has invited the change
beforehand. By submitting an invited contribution, you agree that it may be
included in Volta under the Volta License.

## Building locally

Requirements: macOS 15 or later and Xcode.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
./Scripts/build-app.sh
```

Never commit signing certificates, notarization credentials, personal battery
logs or diagnostic files that may contain device identifiers.
