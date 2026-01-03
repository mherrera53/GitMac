# Setup Guide for GitMac Screenshot Automation

## 📋 Prerequisites

Before running the screenshot automation, you need to:

1. **Add UI Testing Target to Xcode Project**
2. **Install Required Tools** (optional but recommended)
3. **Configure the Demo Repository Path** (if needed)

---

## 🎯 Step 1: Add UI Testing Target

The screenshot automation requires a UI Testing target in your Xcode project.

### Option A: Automatic Setup (Recommended)

Run this command to add the UI testing target automatically:

```bash
cd /Users/mario/Sites/localhost/GitMac
open GitMac.xcodeproj

# Then in Xcode:
# 1. File → New → Target
# 2. Select "UI Testing Bundle" under macOS
# 3. Product Name: GitMacUITests
# 4. Click Finish
```

### Option B: Manual Setup in Xcode

1. **Open the project in Xcode:**
   ```bash
   open GitMac.xcodeproj
   ```

2. **Add UI Testing Target:**
   - In Xcode, go to **File → New → Target...**
   - Under **macOS**, select **UI Testing Bundle**
   - Configure:
     - **Product Name:** `GitMacUITests`
     - **Team:** Your development team
     - **Target to be Tested:** `GitMac`
   - Click **Finish**

3. **Remove default test file:**
   - Xcode will create `GitMacUITests/GitMacUITestsLaunchTests.swift`
   - Delete this file (we already have our custom test file)

4. **Verify the test file is included:**
   - In Project Navigator, locate `Tests/GitMacUITests/GitMacScreenshotTests.swift`
   - Make sure it shows the GitMacUITests target checkbox selected
   - If not, select the file and check the GitMacUITests target in File Inspector

5. **Build the target:**
   ```bash
   xcodebuild -scheme GitMac -target GitMacUITests build
   ```

---

## 🛠️ Step 2: Install Optional Tools

For best results, install image processing tools:

```bash
# ImageMagick (for advanced image effects)
brew install imagemagick

# pngquant (for PNG optimization)
brew install pngquant

# Optional: optipng (alternative optimizer)
brew install optipng

# Check installation
convert --version
pngquant --version
```

**Note:** The automation will work without these tools, but with limited features:
- Without ImageMagick: No shadow/rounded corner effects
- Without pngquant/optipng: No file size optimization

---

## ⚙️ Step 3: Configure Paths

Edit `Screenshots/config/screenshots.json` to set your website repository path:

```json
{
  "paths": {
    "website_repo": "/path/to/your/gitmac-website"
  }
}
```

Or specify it when running:

```bash
./capture-screenshots.sh --website-repo ~/my-website
```

---

## ✅ Verification

Verify everything is set up correctly:

```bash
# Check if UI testing target exists
xcodebuild -list -project GitMac.xcodeproj | grep GitMacUITests

# Try building the UI tests
xcodebuild -scheme GitMac -target GitMacUITests build

# Run a quick test
cd Screenshots
./capture-screenshots.sh --help
```

---

## 🚀 First Run

Once setup is complete, run your first screenshot automation:

```bash
cd Screenshots

# Clean run with all steps
./capture-screenshots.sh --clean

# This will:
# ✓ Create demo repository
# ✓ Run UI tests
# ✓ Capture 38+ screenshots
# ✓ Process images
# ✓ Generate metadata
```

Expected output location: `~/gitmac-screenshots/processed/`

---

## 🐛 Troubleshooting

### Error: "Target 'GitMacUITests' not found"

**Solution:** The UI testing target hasn't been added to the project. Follow Step 1 above.

### Error: "xcodebuild: command not found"

**Solution:** Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### Error: "No such file or directory: GitMacScreenshotTests.swift"

**Solution:** The test file should be at:
```
Tests/GitMacUITests/GitMacScreenshotTests.swift
```

Verify it exists:
```bash
ls -la Tests/GitMacUITests/GitMacScreenshotTests.swift
```

### Tests Launch But Screenshots Are Blank

**Possible causes:**
1. App needs time to load UI - increase `screenshotDelay` in the test file
2. Demo repository not created - run `./scripts/prepare-demo-repo.sh` manually
3. UI elements have different identifiers - update test code to match actual UI

### ImageMagick Not Found

**Solution:**
```bash
# Check if installed
brew list imagemagick

# If not installed
brew install imagemagick

# Verify
convert --version
```

---

## 📚 Next Steps

After successful setup:

1. **Customize Screenshots** - Edit `GitMacScreenshotTests.swift` to add/remove tests
2. **Adjust Image Settings** - Modify `config/screenshots.json`
3. **Integrate with CI/CD** - See `README.md` for GitHub Actions example
4. **Deploy to Website** - Use `--deploy` flag when running

---

## 💡 Tips

- **Run tests from Xcode** for debugging: Open `GitMac.xcodeproj`, select GitMacUITests scheme, press ⌘+U
- **View individual screenshots** in Xcode test results (Report Navigator)
- **Clean between runs** with `--clean` flag to ensure fresh screenshots
- **Test incrementally** - use `--skip-demo` or `--skip-tests` to skip steps

---

## 📞 Support

If you encounter issues:

1. Check this setup guide
2. Review the main `README.md`
3. Check test output logs in `~/gitmac-screenshots/test-output.log`
4. Open an issue on GitHub with error details

---

**Ready to capture amazing screenshots! 📸**
