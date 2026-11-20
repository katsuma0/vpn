#!/usr/bin/env ruby
# Rebuilds Hop.xcodeproj from the folders in this repo.
# You only need this after adding, moving or deleting source files:
#
#   gem install xcodeproj
#   ruby scripts/generate_project.rb
#
require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
Dir.chdir(ROOT)

PROJECT_PATH = 'Hop.xcodeproj'
IOS_VERSION = '16.0'
MACOS_VERSION = '13.0'

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH, false, 56)
project.root_object.attributes['LastSwiftUpdateCheck'] = '1600'
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.development_region = 'en'
project.root_object.known_regions = %w[en Base]

main = project.main_group

# ---------------------------------------------------------------- files

def add_tree(group, dir)
  refs = []
  Dir.children(dir).sort.each do |entry|
    next if entry.start_with?('.')
    full = File.join(dir, entry)
    if File.directory?(full) && !entry.end_with?('.xcassets')
      sub = group.new_group(entry, entry)
      refs.concat(add_tree(sub, full))
    else
      refs << group.new_file(entry)
    end
  end
  refs
end

def swift(refs)
  refs.select { |r| r.path.end_with?('.swift') }
end

config_ref = main.new_file('Config.xcconfig')
main.new_file('README.md')
app_refs = add_tree(main.new_group('App', 'App'), 'App')
shared_refs = add_tree(main.new_group('Shared', 'Shared'), 'Shared')
tunnel_refs = add_tree(main.new_group('Tunnel', 'Tunnel'), 'Tunnel')
test_refs = add_tree(main.new_group('Tests', 'Tests'), 'Tests')
wgkit_refs = add_tree(main.new_group('WireGuardKit', 'WireGuardKit'), 'WireGuardKit')
wgkit_sources = wgkit_refs.select { |r| r.path.end_with?('.swift', '.c') }

assets_ref = app_refs.find { |r| r.path.end_with?('.xcassets') }
mac_only_app = app_refs.select { |r| r.real_path.to_s.include?('/App/macOS/') && r.path.end_with?('.swift') }
shared_app_swift = swift(app_refs) - mac_only_app

# Everything builds on the same xcconfig.
project.build_configurations.each do |config|
  config.base_configuration_reference = config_ref
  config.build_settings.merge!(
    'SWIFT_VERSION' => '5.0',
    'MARKETING_VERSION' => '1.0',
    'CURRENT_PROJECT_VERSION' => '1',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CLANG_ENABLE_MODULES' => 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO',
    'ENABLE_BITCODE' => 'NO',
  )
end

# ---------------------------------------------------------------- WireGuard

# WireGuardKit's sources compile straight into each tunnel extension (see
# WireGuardKit/README.md). The Go engine lands in the build products folder
# as libwg-go.a, built by the WireGuardGoBridge targets below.
wg_go_lib = project.products_group.new_reference('libwg-go.a', :built_products)
wg_go_lib.last_known_file_type = 'archive.ar'
wg_go_lib.include_in_index = '0'

# ---------------------------------------------------------------- helpers

def strip_default_frameworks(target)
  target.frameworks_build_phase.files.to_a.each do |file|
    ref = file.file_ref
    file.remove_from_project
    ref.remove_from_project if ref && ref.referrers.empty?
  end
end

def set(target, settings)
  target.build_configurations.each { |c| c.build_settings.merge!(settings) }
end

# Builds wireguard-go into libwg-go.a, which WireGuardKit links against.
def go_bridge(project, name, sdk, deployment_key, version)
  target = project.new(Xcodeproj::Project::Object::PBXLegacyTarget)
  target.name = name
  target.product_name = name
  target.build_tool_path = '/usr/bin/make'
  target.build_arguments_string = '$(ACTION)'
  target.build_working_directory = '$(PROJECT_DIR)/WireGuardKit/Go'
  target.pass_build_settings_in_environment = '1'
  list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
  list.default_configuration_name = 'Release'
  list.default_configuration_is_visible = '0'
  %w[Debug Release].each do |config_name|
    config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    config.name = config_name
    config.build_settings = {
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'SDKROOT' => sdk,
      'SUPPORTED_PLATFORMS' => sdk,
      deployment_key => version,
    }
    list.build_configurations << config
  end
  target.build_configuration_list = list
  project.targets << target
  target
end

def embed_extension(app, extension)
  phase = app.new_copy_files_build_phase('Embed Foundation Extensions')
  phase.symbol_dst_subfolder_spec = :plug_ins
  file = phase.add_file_reference(extension.product_reference, true)
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  app.add_dependency(extension)
end

# ---------------------------------------------------------------- targets

platforms = [
  { key: 'iOS', platform: :ios, sdk: 'iphoneos', deploy: 'IPHONEOS_DEPLOYMENT_TARGET', version: IOS_VERSION },
  { key: 'macOS', platform: :osx, sdk: 'macosx', deploy: 'MACOSX_DEPLOYMENT_TARGET', version: MACOS_VERSION },
]

app_targets = {}

platforms.each do |p|
  bridge = go_bridge(project, "WireGuardGoBridge#{p[:key]}", p[:sdk], p[:deploy], p[:version])

  # Packet tunnel extension
  ext = project.new_target(:app_extension, "HopTunnel-#{p[:key]}", p[:platform], p[:version], nil, :swift, 'HopTunnel')
  strip_default_frameworks(ext)
  ext.add_file_references(swift(tunnel_refs) + wgkit_sources + shared_refs.select { |r| %w[WireGuardConfig.swift TunnelKeys.swift].include?(r.path) })
  ext.frameworks_build_phase.add_file_reference(wg_go_lib, true)
  ext.add_dependency(bridge)
  ext_settings = {
    'PRODUCT_NAME' => 'HopTunnel',
    'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_PREFIX).hop.tunnel',
    'INFOPLIST_FILE' => 'Tunnel/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'Hop Tunnel',
    'CODE_SIGN_ENTITLEMENTS' => "Tunnel/#{p[:key]}/HopTunnel.entitlements",
    'SKIP_INSTALL' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'SWIFT_OBJC_BRIDGING_HEADER' => 'Tunnel/HopTunnel-Bridging-Header.h',
    'SWIFT_VERSION' => '5.0',
    'SUPPORTED_PLATFORMS' => p[:sdk],
  }
  if p[:platform] == :ios
    ext_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    ext_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  else
    ext_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks', '@executable_path/../../../../Frameworks']
    ext_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
    ext_settings['ENABLE_APP_SANDBOX'] = 'YES'
  end
  set(ext, ext_settings)

  # App
  app = project.new_target(:application, "Hop-#{p[:key]}", p[:platform], p[:version], nil, :swift, 'Hop')
  strip_default_frameworks(app)
  sources = shared_app_swift + swift(shared_refs)
  sources += mac_only_app if p[:platform] == :osx
  app.add_file_references(sources)
  app.add_resources([assets_ref])
  embed_extension(app, ext)
  app_settings = {
    'PRODUCT_NAME' => 'Hop',
    'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_PREFIX).hop',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'Hop',
    'CODE_SIGN_ENTITLEMENTS' => "App/#{p[:key]}/Hop.entitlements",
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'ENABLE_PREVIEWS' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'SUPPORTED_PLATFORMS' => p[:sdk],
  }
  if p[:platform] == :ios
    app_settings.merge!(
      'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks'],
      'TARGETED_DEVICE_FAMILY' => '1,2',
      'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
      'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
      'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone' => 'UIInterfaceOrientationPortrait',
      'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad' => 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    )
  else
    app_settings.merge!(
      'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/../Frameworks'],
      'ENABLE_HARDENED_RUNTIME' => 'YES',
      'ENABLE_APP_SANDBOX' => 'YES',
      'COMBINE_HIDPI_IMAGES' => 'YES',
      'INFOPLIST_KEY_LSApplicationCategoryType' => 'public.app-category.utilities',
      'INFOPLIST_KEY_NSHumanReadableCopyright' => '',
    )
  end
  set(app, app_settings)
  app_targets[p[:key]] = app
end

# Unit tests: plain logic only, so they run on any Mac with no signing setup
# and without building Go.
tests = project.new_target(:unit_test_bundle, 'HopTests', :osx, MACOS_VERSION, nil, :swift, 'HopTests')
strip_default_frameworks(tests)
tests.add_file_references(swift(test_refs) + swift(shared_refs))
set(tests, {
  'PRODUCT_NAME' => 'HopTests',
  'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_PREFIX).hop.tests',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'SWIFT_VERSION' => '5.0',
  'CODE_SIGN_STYLE' => 'Manual',
  'CODE_SIGN_IDENTITY' => '-',
  'DEVELOPMENT_TEAM' => '',
  'PROVISIONING_PROFILE_SPECIFIER' => '',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/../Frameworks', '@loader_path/../Frameworks'],
})

# ---------------------------------------------------------------- schemes

app_targets.each do |key, app|
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(app)
  scheme.set_launch_target(app)
  scheme.add_test_target(tests) if key == 'macOS'
  scheme.save_as(PROJECT_PATH, "Hop-#{key}", true)
end

test_scheme = Xcodeproj::XCScheme.new
test_scheme.add_build_target(tests, false)
test_scheme.add_test_target(tests)
test_scheme.save_as(PROJECT_PATH, 'HopTests', true)

project.sort(groups_position: :above)
project.save
puts "Wrote #{PROJECT_PATH}"
