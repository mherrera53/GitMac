# External Frameworks

This directory contains external frameworks required by GitMac.

## GhosttyKit.xcframework

GitMac uses the Ghostty terminal emulator for advanced terminal features. The framework is required for the application to build and run.

### Automatic Setup

The recommended way to set up the framework is using the provided script:

```bash
./scripts/setup-ghostty.sh
```

This script will:
1. Check if the framework already exists
2. Download `GhosttyKit.xcframework.zip` from the [dependencies release](https://github.com/mherrera53/GitMac/releases/tag/dependencies)
3. Extract it to this directory

### Manual Setup

If you prefer to set up manually:

1. Download the framework:
   ```bash
   curl -L -o GhosttyKit.xcframework.zip \
     https://github.com/mherrera53/GitMac/releases/download/dependencies/GhosttyKit.xcframework.zip
   ```

2. Extract to this directory:
   ```bash
   unzip GhosttyKit.xcframework.zip -d Frameworks/
   ```

3. Verify the structure:
   ```
   Frameworks/
   └── GhosttyKit.xcframework/
       ├── Info.plist
       ├── macos-arm64_x86_64/
       │   ├── Headers/
       │   │   ├── ghostty.h
       │   │   └── module.modulemap
       │   └── libghostty.a
       ├── ios-arm64/
       └── ios-arm64-simulator/
   ```

### For CI/CD

GitHub Actions workflows automatically run `./scripts/setup-ghostty.sh` to download and set up the framework before building.

### Note

The `Frameworks/` directory is listed in `.gitignore` to avoid committing large binary files. The framework is distributed via GitHub Releases instead.

**Source**: The framework is built from [ghostty-org/ghostty](https://github.com/ghostty-org/ghostty) and packaged in the GitMac dependencies release.
