#!/bin/bash

#==============================================================================
# GitMac Professional Screenshot Automation
#==============================================================================
#
# Captures comprehensive screenshots of all GitMac interfaces
# Organized by category in both Light and Dark mode
#
# Usage:
#   ./capture_screenshots.sh [all|light|dark|category]
#
#==============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/fastlane/screenshots"
RESULTS_DIR="$PROJECT_DIR/fastlane/test_results"
DEMO_REPO="/Users/mario/gitmac-demo-repo"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() { echo -e "${BLUE}→${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Ensure demo repository exists
setup_demo_repo() {
    print_step "Checking demo repository..."
    if [ ! -d "$DEMO_REPO" ]; then
        print_step "Creating demo repository at $DEMO_REPO"
        mkdir -p "$DEMO_REPO" && cd "$DEMO_REPO"
        git init
        echo "# GitMac Demo Repository" > README.md
        git add README.md && git commit -m "Initial commit"
        mkdir -p src/{models,services,utils}
        echo 'struct User { let id: UUID; let name: String }' > src/models/User.swift
        git add . && git commit -m "Add User model"
        echo 'class UserService { func getUsers() {} }' > src/services/UserService.swift
        git add . && git commit -m "Add UserService"
        git checkout -b feature/auth
        echo 'class AuthManager { func login() {} }' > src/services/AuthManager.swift
        git add . && git commit -m "Add AuthManager"
        git checkout master
        echo 'func formatDate() {}' > src/utils/DateUtils.swift
        git add . && git commit -m "Add date utilities"
        git tag -a v1.0.0 -m "Version 1.0.0"
        echo "// TODO: More utils" >> src/utils/DateUtils.swift
        cd "$PROJECT_DIR"
        print_success "Demo repository created"
    else
        print_success "Demo repository exists"
    fi
}

clean_output() {
    print_step "Cleaning output directories..."
    rm -rf "$SCREENSHOTS_DIR/captures" 2>/dev/null || true
    mkdir -p "$SCREENSHOTS_DIR/captures"
    mkdir -p "$RESULTS_DIR"
    print_success "Output directories ready"
}

build_tests() {
    print_step "Building UI test target..."
    cd "$PROJECT_DIR"
    xcodebuild build-for-testing \
        -project GitMac.xcodeproj \
        -scheme GitMacUITests \
        -destination 'platform=macOS' \
        -quiet 2>&1 | grep -E "(error:|Build)" || true
    print_success "UI tests built"
}

run_tests() {
    local test_class=$1
    local output_name=$2
    
    print_step "Running $test_class..."
    xcodebuild test-without-building \
        -project GitMac.xcodeproj \
        -scheme GitMacUITests \
        -destination 'platform=macOS' \
        -only-testing:"GitMacUITests/$test_class" \
        -resultBundlePath "$RESULTS_DIR/${output_name}_$TIMESTAMP.xcresult" \
        2>&1 | grep -E "(Test Case|passed|failed|📸)" || true
}

run_all_light() {
    print_header "Light Mode Screenshots"
    run_tests "MainWindowLightModeScreenshots" "MainWindow_Light"
    run_tests "CommitGraphLightModeScreenshots" "CommitGraph_Light"
    run_tests "DiffViewerLightModeScreenshots" "DiffViewer_Light"
    run_tests "StagingLightModeScreenshots" "Staging_Light"
    run_tests "DialogsLightModeScreenshots" "Dialogs_Light"
    run_tests "SettingsLightModeScreenshots" "Settings_Light"
    run_tests "BottomPanelLightModeScreenshots" "BottomPanel_Light"
    run_tests "IntegrationsLightModeScreenshots" "Integrations_Light"
    run_tests "TerminalLightModeScreenshots" "Terminal_Light"
    run_tests "AdvancedFeaturesLightModeScreenshots" "Advanced_Light"
    run_tests "WelcomeLightModeScreenshots" "Welcome_Light"
}

run_all_dark() {
    print_header "Dark Mode Screenshots"
    run_tests "MainWindowDarkModeScreenshots" "MainWindow_Dark"
    run_tests "CommitGraphDarkModeScreenshots" "CommitGraph_Dark"
    run_tests "DiffViewerDarkModeScreenshots" "DiffViewer_Dark"
    run_tests "StagingDarkModeScreenshots" "Staging_Dark"
    run_tests "DialogsDarkModeScreenshots" "Dialogs_Dark"
    run_tests "SettingsDarkModeScreenshots" "Settings_Dark"
    run_tests "BottomPanelDarkModeScreenshots" "BottomPanel_Dark"
    run_tests "IntegrationsDarkModeScreenshots" "Integrations_Dark"
    run_tests "TerminalDarkModeScreenshots" "Terminal_Dark"
    run_tests "AdvancedFeaturesDarkModeScreenshots" "Advanced_Dark"
    run_tests "WelcomeDarkModeScreenshots" "Welcome_Dark"
}

extract_screenshots() {
    print_header "Extracting Screenshots"
    for result in "$RESULTS_DIR"/*.xcresult; do
        [ -f "$result" ] && xcrun xcresulttool get attachments \
            --path "$result" \
            --output-path "$SCREENSHOTS_DIR/captures" 2>/dev/null || true
    done
    print_success "Screenshots extracted to $SCREENSHOTS_DIR/captures"
}

print_summary() {
    print_header "Summary"
    local total=$(find "$SCREENSHOTS_DIR/captures" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${CYAN}Total screenshots:${NC} $total"
    echo -e "${GREEN}Output:${NC} $SCREENSHOTS_DIR/captures"
    print_success "Screenshot automation completed!"
}

main() {
    print_header "GitMac Screenshot Automation"
    local mode="${1:-all}"
    
    setup_demo_repo
    clean_output
    build_tests
    
    case "$mode" in
        all)   run_all_light; run_all_dark ;;
        light) run_all_light ;;
        dark)  run_all_dark ;;
        *)     print_error "Usage: $0 [all|light|dark]" ;;
    esac
    
    extract_screenshots
    print_summary
}

main "$@"
