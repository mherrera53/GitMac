# GitMac Screenshot Automation

Automated screenshot capture system for GitMac documentation and website.

## 🎯 Overview

This system automatically captures, processes, and organizes screenshots of GitMac for use in documentation and the project website. It uses XCTest UI Testing to interact with the application and capture high-quality screenshots.

## 📋 Features

- ✅ **Automated Capture** - 38+ screenshots covering all major features
- ✅ **Multiple Themes** - Light and dark mode variants
- ✅ **Post-Processing** - Resize, optimize, and add effects
- ✅ **Multiple Formats** - Original, web-optimized, and thumbnail versions
- ✅ **Metadata Generation** - JSON metadata for easy integration
- ✅ **Demo Repository** - Realistic Git repository for screenshots
- ✅ **Website Integration** - Direct deployment to website repository

## 🚀 Quick Start

### Prerequisites

1. **Xcode** (15.0 or later)
2. **Git** (2.30.0 or later)
3. **Optional**: ImageMagick for advanced effects

```bash
# Install optional tools
brew install imagemagick pngquant
```

### Basic Usage

```bash
# Make scripts executable
chmod +x Screenshots/capture-screenshots.sh
chmod +x Screenshots/scripts/*.sh

# Run the complete automation
cd Screenshots
./capture-screenshots.sh
```

This will:
1. Create a demo Git repository
2. Run UI tests and capture screenshots
3. Extract screenshots from test results
4. Post-process images (resize, optimize)
5. Generate metadata JSON

### Deploy to Website

```bash
# Deploy screenshots to website repository
./capture-screenshots.sh --deploy --website-repo ~/path/to/website-repo
```

## 📁 Directory Structure

```
Screenshots/
├── capture-screenshots.sh      # Main automation script
├── README.md                    # This file
│
├── config/
│   └── screenshots.json         # Configuration settings
│
└── scripts/
    ├── prepare-demo-repo.sh     # Creates demo Git repository
    ├── extract-screenshots.sh   # Extracts from test results
    ├── process-screenshots.sh   # Post-processes images
    └── generate-metadata.sh     # Generates JSON metadata
```

### Output Structure

```
~/gitmac-screenshots/
├── processed/
│   ├── *.png                    # Main screenshots (max 2560px)
│   ├── *_shadow.png             # Screenshots with shadow effect
│   ├── metadata.json            # Screenshot metadata
│   ├── originals/               # Original unprocessed files
│   ├── web/                     # Web-optimized (1600px)
│   └── thumbnails/              # Thumbnails (400px)
│
├── raw/                         # Extracted raw screenshots
├── results.xcresult/            # XCTest result bundle
└── test-output.log              # Test execution log
```

## 🎨 Screenshot Categories

The automation captures screenshots for:

1. **General** - Main window, sidebar, layouts
2. **Commits & History** - Commit graph, details, history
3. **Branch Management** - Branch list, creation, merging
4. **Diff Viewer** - Inline, split, syntax highlighting
5. **Staging Area** - File staging, line-level staging
6. **Merge & Conflicts** - Conflict resolution UI
7. **Terminal Integration** - Integrated terminal
8. **Plugin System** - Plugin management
9. **Workflow Automation** - Custom workflows
10. **Team Features** - Team profiles, shared settings
11. **Settings** - Preferences and configuration
12. **Themes** - Light and dark mode variations

## ⚙️ Configuration

Edit `config/screenshots.json` to customize:

```json
{
  "paths": {
    "website_repo": "~/gitmac-website"  // Your website repo path
  },
  "image_processing": {
    "max_width": 2560,     // Maximum screenshot width
    "web_width": 1600,     // Web-optimized width
    "thumbnail_width": 400  // Thumbnail width
  },
  "deployment": {
    "auto_deploy": false   // Set to true for automatic deployment
  }
}
```

## 🔧 Advanced Usage

### Command-Line Options

```bash
# Show help
./capture-screenshots.sh --help

# Skip demo repository preparation
./capture-screenshots.sh --skip-demo

# Skip running tests (use existing results)
./capture-screenshots.sh --skip-tests

# Skip post-processing
./capture-screenshots.sh --skip-process

# Clean all previous output
./capture-screenshots.sh --clean

# Deploy to website
./capture-screenshots.sh --deploy

# Specify website repository
./capture-screenshots.sh --deploy --website-repo ~/my-website

# Combine options
./capture-screenshots.sh --clean --deploy
```

### Running Individual Steps

```bash
# 1. Only prepare demo repository
./scripts/prepare-demo-repo.sh

# 2. Only extract screenshots (if tests already ran)
./scripts/extract-screenshots.sh ~/gitmac-screenshots/results.xcresult ~/gitmac-screenshots/raw

# 3. Only post-process
./scripts/process-screenshots.sh ~/gitmac-screenshots/raw ~/gitmac-screenshots/processed

# 4. Only generate metadata
./scripts/generate-metadata.sh ~/gitmac-screenshots/processed > metadata.json
```

### Running Tests from Xcode

You can also run the UI tests directly from Xcode:

1. Open `GitMac.xcodeproj`
2. Select the `GitMacUITests` target
3. Run tests (⌘+U)
4. Screenshots will be attached to test results

## 📸 Screenshot Test Structure

The test suite is organized in `Tests/GitMacUITests/GitMacScreenshotTests.swift`:

```swift
// Light mode tests (test01-test32)
func test01_MainWindow_Hero()
func test05_CommitGraph_Overview()
func test11_DiffView_Inline()
// ... etc

// Dark mode tests (test33-test37)
class GitMacScreenshotTestsDarkMode
func test33_MainWindow_Dark()
// ... etc

// Retina tests (test38)
class GitMacScreenshotTestsRetina
func test38_HeroRetina()
```

### Adding New Screenshot Tests

1. Open `Tests/GitMacUITests/GitMacScreenshotTests.swift`
2. Add a new test method:

```swift
func test39_NewFeature() throws {
    // Navigate to feature
    app.buttons["NewFeature"].click()
    sleep(1)

    // Capture screenshot
    captureScreenshot(named: "39-new-feature-name")
}
```

3. Run the automation script again

## 🌐 Website Integration

### Metadata JSON Format

The generated `metadata.json` provides information about each screenshot:

```json
{
  "generated_at": "2025-12-30T10:30:00Z",
  "version": "1.0",
  "screenshots": [
    {
      "id": "01-hero-main-window",
      "filename": "01-hero-main-window.png",
      "title": "Hero Main Window",
      "category": "general",
      "theme": "light",
      "order": 1,
      "dimensions": {
        "width": 2560,
        "height": 1440
      },
      "filesize": "1.2M",
      "urls": {
        "original": "originals/01-hero-main-window.png",
        "main": "01-hero-main-window.png",
        "web": "web/01-hero-main-window.png",
        "thumbnail": "thumbnails/01-hero-main-window.png"
      }
    }
  ]
}
```

### Using in Your Website

```javascript
// Load metadata
fetch('/screenshots/metadata.json')
  .then(r => r.json())
  .then(data => {
    data.screenshots.forEach(screenshot => {
      // Use screenshot.urls.web for web display
      // Use screenshot.urls.thumbnail for previews
    });
  });
```

## 🔄 Automation with CI/CD

### GitHub Actions Example

Create `.github/workflows/screenshots.yml`:

```yaml
name: Update Screenshots

on:
  workflow_dispatch:  # Manual trigger
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday

jobs:
  screenshots:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: brew install imagemagick pngquant

      - name: Run screenshot automation
        run: |
          cd Screenshots
          chmod +x capture-screenshots.sh
          ./capture-screenshots.sh --clean

      - name: Upload screenshots
        uses: actions/upload-artifact@v3
        with:
          name: screenshots
          path: ~/gitmac-screenshots/processed/
```

## 🐛 Troubleshooting

### Tests Not Finding UI Elements

The app needs to support UI testing. Make sure:
- Accessibility identifiers are set on UI elements
- The app is built with testability enabled

### Screenshots Are Blank

- Ensure the app has enough time to load (adjust `screenshotDelay`)
- Check that the demo repository was created correctly
- Verify the app launches successfully in tests

### Extraction Fails

- Make sure Xcode Command Line Tools are installed:
  ```bash
  xcode-select --install
  ```
- Check that the result bundle path is correct

### Low Quality Images

- Adjust quality settings in `config/screenshots.json`
- Use higher resolution settings in the tests
- Ensure optimization tools are installed correctly

## 📝 Maintenance

### Updating Screenshots

When you add new features to GitMac:

1. Add corresponding UI test methods
2. Update categories in `config/screenshots.json` if needed
3. Run the automation script
4. Review screenshots before deploying

### Keeping Tests Stable

- Use accessibility identifiers instead of visual search
- Add appropriate wait times for animations
- Test on a clean app state (use demo repo)

## 📚 Additional Resources

- [XCTest UI Testing Documentation](https://developer.apple.com/documentation/xctest)
- [Screenshot Best Practices](https://developer.apple.com/design/human-interface-guidelines/screenshots)
- [Image Optimization Guide](https://imageoptim.com/mac)

## 🤝 Contributing

When contributing screenshots:

1. Follow the naming convention: `{order}-{category}-{description}.png`
2. Test on both light and dark modes
3. Ensure UI elements are clearly visible
4. Add metadata to test descriptions

## 📄 License

MIT License - Same as GitMac project

---

**Made with ❤️ for the GitMac project**

For questions or issues, please open an issue on GitHub.
