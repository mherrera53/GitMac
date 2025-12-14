# GitMac - Release & Installation Guide

## 🎯 Quick Install (Recommended)

### Option 1: Automated Script

1. **Make the script executable:**
   ```bash
   chmod +x release.sh
   ```

2. **Run the release script:**
   ```bash
   ./release.sh
   ```

3. **Follow the prompts** - The script will:
   - ✅ Clean build folder
   - ✅ Build Release configuration
   - ✅ Install to /Applications
   - ✅ Set permissions
   - ✅ Remove quarantine
   - ✅ (Optional) Create DMG installer

---

### Option 2: Manual Xcode Build

If the script doesn't work or you prefer manual control:

#### Step 1: Open in Xcode
```bash
open *.xcodeproj
```

#### Step 2: Select Release Scheme
1. In Xcode, click on the scheme selector (next to Stop button)
2. Select "Edit Scheme..."
3. Under "Run" → "Info" → "Build Configuration"
4. Select **Release**
5. Click "Close"

#### Step 3: Build for Running (Mac - My Mac)
1. Select "My Mac" as the destination
2. Press **Cmd+B** to build
3. Or Product → Build (Cmd+B)

#### Step 4: Archive for Distribution
1. Product → Archive (or Cmd+Shift+B)
2. Wait for build to complete
3. Organizer window will open

#### Step 5: Export App
1. In Organizer, select your archive
2. Click "Distribute App"
3. Select "Copy App"
4. Choose destination folder
5. Click "Export"

#### Step 6: Install
1. Locate the exported .app file
2. Drag it to /Applications folder
3. If macOS blocks it, right-click → Open

---

### Option 3: Build from Terminal

```bash
# Clean previous builds
xcodebuild clean -project GitMac.xcodeproj -scheme GitMac -configuration Release

# Build for Release
xcodebuild build \
    -project GitMac.xcodeproj \
    -scheme GitMac \
    -configuration Release \
    -derivedDataPath ./build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO

# Find and copy to Applications
APP_PATH=$(find ./build -name "*.app" | head -n 1)
cp -R "$APP_PATH" /Applications/

# Remove quarantine
xattr -cr /Applications/GitMac.app

# Launch
open /Applications/GitMac.app
```

---

## 🔧 Troubleshooting

### "xcrun: error: unable to find utility \"xcodebuild\""

**Solution:** Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### "xcodebuild: error: 'GitMac.xcworkspace' does not exist"

**Solution:** Use .xcodeproj instead:
```bash
# Find your project file
ls -la *.xcodeproj

# Use it in the build command
xcodebuild -project YourProject.xcodeproj -scheme YourScheme
```

### "No scheme specified and no default"

**Solution:** List available schemes and select one:
```bash
# List schemes
xcodebuild -list -project *.xcodeproj

# Build with specific scheme
xcodebuild -project *.xcodeproj -scheme "YourScheme"
```

### Build succeeds but app not found

**Solution:** Find the app manually:
```bash
# Search for .app bundle
find ./build -name "*.app"

# Example output: ./build/Build/Products/Release/GitMac.app
```

### "GitMac.app is damaged and can't be opened"

**Solution:** Remove quarantine attribute:
```bash
xattr -cr /Applications/GitMac.app
```

Or allow in System Preferences:
1. System Settings → Privacy & Security
2. Scroll to "Security" section
3. Click "Open Anyway" next to the blocked app

### App crashes on launch

**Solution:** Check Console for crash logs:
```bash
# Open Console.app
open /System/Applications/Utilities/Console.app

# Or view logs in Terminal
log show --predicate 'process == "GitMac"' --last 5m
```

---

## 📦 Creating a Distributable DMG

### Option 1: Using create-dmg tool

1. **Install create-dmg:**
   ```bash
   brew install create-dmg
   ```

2. **Create DMG:**
   ```bash
   create-dmg \
       --volname "GitMac" \
       --volicon "GitMac.app/Contents/Resources/AppIcon.icns" \
       --window-pos 200 120 \
       --window-size 600 400 \
       --icon-size 100 \
       --icon "GitMac.app" 175 120 \
       --hide-extension "GitMac.app" \
       --app-drop-link 425 120 \
       "GitMac-1.0.0.dmg" \
       "/Applications/GitMac.app"
   ```

### Option 2: Using hdiutil (built-in)

```bash
# Create temporary folder
mkdir dmg_temp
cp -R /Applications/GitMac.app dmg_temp/
ln -s /Applications dmg_temp/Applications

# Create DMG
hdiutil create -volname "GitMac" \
    -srcfolder dmg_temp \
    -ov -format UDZO \
    GitMac-1.0.0.dmg

# Clean up
rm -rf dmg_temp
```

---

## 🚀 Performance Testing After Install

### Run Performance Tests

1. Open Xcode
2. Press **Cmd+U** to run tests
3. Check test results for:
   - ✅ Parse 100k lines < 1.5s
   - ✅ Memory < 100 MB
   - ✅ Cache hit rate > 80%

### Profile with Instruments

1. Product → Profile (Cmd+I)
2. Select "Time Profiler"
3. Record while scrolling large diff
4. Verify:
   - ✅ Frame time p95 < 16ms (60 FPS)
   - ✅ No memory leaks
   - ✅ CPU usage reasonable

### Manual Performance Check

1. Open a large file diff (10k+ lines)
2. Verify:
   - ✅ Loads in < 2 seconds
   - ✅ Scroll is smooth (no stutter)
   - ✅ Memory usage stable
   - ✅ Status bar shows "Large File Mode" if > 50k lines

---

## 📊 Build Configurations

### Debug vs Release

| Feature | Debug | Release |
|---------|-------|---------|
| **Optimization** | None (-Onone) | Aggressive (-O) |
| **Symbols** | Yes | No |
| **Assertions** | Enabled | Disabled |
| **Speed** | Slower | Faster (2-5x) |
| **Size** | Larger | Smaller |
| **Use Case** | Development | Distribution |

### Recommended Build Settings

```swift
// In your .xcconfig or Build Settings

// Release Configuration
SWIFT_OPTIMIZATION_LEVEL = -O
SWIFT_COMPILATION_MODE = wholemodule
GCC_OPTIMIZATION_LEVEL = s  // Optimize for size
DEPLOYMENT_POSTPROCESSING = YES  // Strip symbols
STRIP_INSTALLED_PRODUCT = YES
DEAD_CODE_STRIPPING = YES
ENABLE_BITCODE = NO  // Not needed for macOS

// Performance
SWIFT_ENFORCE_EXCLUSIVE_ACCESS = compile-time-only
ENABLE_TESTABILITY = NO  // Disable in Release
```

---

## 🎯 Checklist Before Release

- [ ] All tests pass (Cmd+U)
- [ ] No compiler warnings
- [ ] Performance targets met:
  - [ ] Parse 100k lines < 1.5s
  - [ ] Memory < 100 MB
  - [ ] Scroll 60 FPS
- [ ] App icon set
- [ ] Version number updated
- [ ] Build number incremented
- [ ] Release notes written
- [ ] Code signing configured (if distributing)
- [ ] Notarization done (if distributing outside App Store)

---

## 🔐 Code Signing & Notarization (Optional)

### For Distribution Outside Your Mac

If you want to share GitMac with others:

1. **Get a Developer ID:**
   - Requires Apple Developer account ($99/year)
   - https://developer.apple.com/

2. **Sign the app:**
   ```bash
   codesign --deep --force --verify --verbose \
       --sign "Developer ID Application: Your Name (TEAMID)" \
       /Applications/GitMac.app
   ```

3. **Notarize with Apple:**
   ```bash
   # Create archive
   ditto -c -k --keepParent /Applications/GitMac.app GitMac.zip
   
   # Submit for notarization
   xcrun notarytool submit GitMac.zip \
       --apple-id "your@email.com" \
       --password "app-specific-password" \
       --team-id "TEAMID" \
       --wait
   
   # Staple ticket to app
   xcrun stapler staple /Applications/GitMac.app
   ```

---

## 🎉 Success!

Once installed, you can:

1. **Launch from Applications:**
   ```bash
   open /Applications/GitMac.app
   ```

2. **Or from Spotlight:**
   - Press Cmd+Space
   - Type "GitMac"
   - Press Enter

3. **Check version:**
   - GitMac → About GitMac
   - Should show version 1.0.0

---

## 📚 What's New in This Release

### Performance Optimizations ✨

- **DiffEngine** with streaming and LFM
- **DiffCache** with LRU eviction  
- **TiledDiffView** for 50k+ line files
- **Automatic LFM** activation
- **Performance tests** with targets

### Expected Improvements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Parse 100k lines | 5-10s | < 1.5s | **3-7x faster** |
| Memory (large files) | 200-500 MB | < 100 MB | **2-5x less** |
| Scroll FPS | 20-30 | 60 | **2-3x smoother** |
| Max file size | ~50k lines | 500k+ lines | **10x larger** |

---

**Need help?** Check the troubleshooting section above or open an issue! 🚀
