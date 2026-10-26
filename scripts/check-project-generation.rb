#!/usr/bin/env ruby
require 'xcodeproj'
require 'yaml'
require 'json'
require 'tmpdir'
require 'securerandom'
require 'digest'
require 'fileutils'

root = File.expand_path('..', __dir__)
original_path = File.join(root, 'GitMac.xcodeproj')
original_hash = Digest::SHA256.file(File.join(original_path, 'project.pbxproj')).hexdigest
original = Xcodeproj::Project.open(original_path)
spec = YAML.load_file(File.join(root, 'project.yml'))
name = "GitMacValidation-#{SecureRandom.hex(8)}"
spec['name'] = name
generated_path = File.join(root, name + '.xcodeproj')
raise 'Refuse to overwrite a project' if File.exist?(generated_path)
keep = ARGV.include?('--keep')

def snapshot(project, root)
  { 'settings' => project.build_configurations.to_h { |c| [c.name, c.build_settings] },
    'packages' => project.root_object.package_references.map { |r| [r.repositoryURL, r.requirement] }.sort,
    'targets' => project.targets.to_h do |target|
      [target.name, { 'product' => target.product_type,
        'settings' => target.build_configurations.to_h { |c| [c.name, c.build_settings] },
        'sources' => target.source_build_phase.files.map { |f| [f.file_ref.real_path.to_s.delete_prefix(root + '/'), f.settings] }.sort,
        'resources' => target.resources_build_phase.files.map { |f| [f.file_ref.real_path.to_s.delete_prefix(root + '/'), f.settings] }.sort,
        'products' => target.package_product_dependencies.map(&:product_name).sort,
        'dependencies' => target.dependencies.map { |d| d.target.name }.sort }]
    end }
end

begin
  Dir.mktmpdir('gitmac-project-spec-') do |temporary|
    spec_path = File.join(temporary, 'project.yml')
    File.write(spec_path, YAML.dump(spec))
    command = ['xcodegen', 'generate', '--spec', spec_path, '--project', root, '--project-root', root, '--no-env', '--quiet']
    raise 'XcodeGen failed' unless system(*command)
    first_hash = Digest::SHA256.file(File.join(generated_path, 'project.pbxproj')).hexdigest
    raise 'Second generation failed' unless system(*command)
    raise 'Generation is not deterministic' unless first_hash == Digest::SHA256.file(File.join(generated_path, 'project.pbxproj')).hexdigest
  end
  before = snapshot(original, root)
  after = snapshot(Xcodeproj::Project.open(generated_path), root)
  errors = []
  errors << 'Project configuration drift' unless before['settings'] == after['settings']
  errors << 'Package requirement drift' unless before['packages'] == after['packages']
  before['targets'].each do |name, target|
    generated = after['targets'][name]
    errors << "Missing target #{name}" unless generated
    next unless generated
    target.each { |key, value| errors << "#{name}: #{key} changed" unless generated[key] == value }
  end
  errors << 'Production tests target missing' unless after['targets'].key?('GitMacTests')
  raise errors.join('; ') unless errors.empty?
  raise 'Original project was modified' unless original_hash == Digest::SHA256.file(File.join(original_path, 'project.pbxproj')).hexdigest
  resolved = File.join(original_path, 'project.xcworkspace/xcshareddata/swiftpm/Package.resolved')
  if File.file?(resolved)
    destination = File.join(generated_path, 'project.xcworkspace/xcshareddata/swiftpm')
    FileUtils.mkdir_p(destination)
    FileUtils.cp(resolved, destination)
  end
  puts JSON.pretty_generate({ 'passed' => true, 'originalPreserved' => true, 'deterministic' => true,
    'project' => keep ? generated_path : 'temporary, removed after validation',
    'targets' => after['targets'].keys, 'applicationSources' => after['targets']['GitMac']['sources'].length,
    'applicationResources' => after['targets']['GitMac']['resources'].length,
    'note' => 'Structure only; build and test outcomes require separate evidence.' })
ensure
  # Only the unique, nonexistent-before-this-run generated project is removable.
  if !keep && File.basename(generated_path) == name + '.xcodeproj' && File.dirname(generated_path) == root
    FileUtils.remove_entry_secure(generated_path) if File.directory?(generated_path)
  end
end
