#!/usr/bin/env ruby
# One-time, read-only migration aid. Prints a spec; never overwrites a project.
require 'xcodeproj'
require 'yaml'

project = Xcodeproj::Project.open(File.expand_path('../GitMac.xcodeproj', __dir__))
root = File.expand_path('..', __dir__)
relative = ->(ref) { ref.real_path.to_s.delete_prefix(root + '/') }
packages = {}
names = {}
project.root_object.package_references.each do |ref|
  name = File.basename(ref.repositoryURL).delete_suffix('.git')
  names[ref.uuid] = name
  requirement = ref.requirement
  raise 'Review unsupported package requirement' unless requirement['kind'] == 'upToNextMajorVersion'
  packages[name] = { 'url' => ref.repositoryURL, 'from' => requirement['minimumVersion'] }
end
targets = {}
project.targets.each do |target|
  type = { 'com.apple.product-type.application' => 'application',
           'com.apple.product-type.bundle.ui-testing' => 'bundle.ui-testing' }.fetch(target.product_type)
  sources = target.source_build_phase.files.map { |f| { 'path' => relative.call(f.file_ref), 'buildPhase' => 'sources' } }
  resources = target.resources_build_phase.files.map { |f| { 'path' => relative.call(f.file_ref), 'buildPhase' => 'resources' } }
  target.build_phases.each do |phase|
    raise 'Review custom build phase before migration' unless %w[PBXSourcesBuildPhase PBXResourcesBuildPhase PBXFrameworksBuildPhase].include?(phase.isa)
    raise 'Review per-file settings before migration' if phase.files.any? { |f| f.settings && !f.settings.empty? }
  end
  dependencies = target.package_product_dependencies.map { |d| { 'package' => names.fetch(d.package.uuid), 'product' => d.product_name } }
  target.dependencies.each { |d| dependencies << { 'target' => d.target.name } }
  targets[target.name] = { 'type' => type, 'platform' => 'macOS', 'sources' => sources + resources,
    'dependencies' => dependencies, 'settings' => { 'configs' => target.build_configurations.to_h { |c| [c.name, c.build_settings] } } }
end
targets['GitMacTests'] = { 'type' => 'bundle.unit-test', 'platform' => 'macOS',
  'sources' => [{ 'path' => 'Tests/GitMacTests', 'excludes' => ['Info.plist'], 'buildPhase' => 'sources' }],
  'dependencies' => [{ 'target' => 'GitMac' }],
  'settings' => { 'base' => { 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.gitmac.GitMacTests',
    'PRODUCT_NAME' => '$(TARGET_NAME)', 'PRODUCT_MODULE_NAME' => 'GitMacTests',
    'HEADER_SEARCH_PATHS' => ['$(inherited)', '$(PROJECT_DIR)/Frameworks/GhosttyKit.xcframework/macos-arm64_x86_64/Headers'],
    'FRAMEWORK_SEARCH_PATHS' => ['$(inherited)', '$(PROJECT_DIR)/Frameworks'],
    'GENERATE_INFOPLIST_FILE' => 'YES', 'INFOPLIST_FILE' => 'Tests/GitMacTests/Info.plist',
    'SWIFT_VERSION' => '5.0', 'CODE_SIGN_IDENTITY' => '-', 'CODE_SIGN_STYLE' => 'Manual',
    'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/GitMac.app/Contents/MacOS/GitMac', 'BUNDLE_LOADER' => '$(TEST_HOST)' } } }
spec = { 'name' => 'GitMac', 'options' => { 'minimumXcodeGenVersion' => '2.44.0', 'settingPresets' => 'none',
  'deploymentTarget' => { 'macOS' => '14.0' }, 'createIntermediateGroups' => true },
  'configs' => { 'Debug' => 'debug', 'Release' => 'release' },
  'settings' => { 'configs' => project.build_configurations.to_h { |c| [c.name, c.build_settings] } },
  'packages' => packages, 'targets' => targets,
  'schemes' => { 'GitMac' => { 'build' => { 'targets' => { 'GitMac' => 'all', 'GitMacTests' => ['test'], 'GitMacUITests' => ['test'] } },
    'test' => { 'config' => 'Debug', 'targets' => ['GitMacTests'], 'gatherCoverageData' => true } },
    'GitMacUI' => { 'build' => { 'targets' => { 'GitMac' => 'all', 'GitMacUITests' => ['test'] } },
      'test' => { 'config' => 'Debug', 'targets' => ['GitMacUITests'] } } } }
puts YAML.dump(spec)
