#!/usr/bin/env ruby
# Adds the v1.7 Apple Watch targets to ios/Runner.xcodeproj. Idempotent: it
# exits without changes if CanopyWatch already exists.
#
#   gem install --user-install xcodeproj   # (danserver has it; so does any
#   ruby tools/add-watch-targets.rb        #  Mac with CocoaPods)
#
# Kept as a script, not hand-edited pbxproj, so the change is reviewable and
# reproducible. Targets:
#   CanopyWatch          watchOS app (single-target), embedded in Runner
#   CanopyWatchWidgets   watchOS WidgetKit extension (the complications),
#                        embedded in CanopyWatch
# Both share ios/CanopyWatchShared/*.swift and the App Group
# group.com.danjjohnson.canopy. Runner gains ios/Runner/WatchBridge.swift.
require 'xcodeproj'

TEAM = 'H637CCV562'
WATCHOS = '10.0'
root = File.expand_path('../ios', __dir__)
proj = Xcodeproj::Project.open(File.join(root, 'Runner.xcodeproj'))

if proj.targets.any? { |t| t.name == 'CanopyWatch' }
  puts 'CanopyWatch already present; nothing to do.'
  exit 0
end

runner = proj.targets.find { |t| t.name == 'Runner' }
watch_xcconfig = proj.main_group.find_subpath('Flutter', false)
                     .new_reference('Flutter/Watch.xcconfig')

def group_for(proj, name)
  proj.main_group.find_subpath(name, false) || proj.main_group.new_group(name, name)
end

def configure(target, xcconfig, settings)
  release = target.build_configurations.find { |c| c.name == 'Release' }
  unless target.build_configurations.any? { |c| c.name == 'Profile' }
    profile = target.project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    profile.name = 'Profile'
    profile.build_settings = release.build_settings.dup
    target.build_configuration_list.build_configurations << profile
  end
  target.build_configurations.each do |c|
    c.base_configuration_reference = xcconfig
    c.build_settings.merge!(settings)
    # xcodeproj defaults we do not want: no AccentColor asset exists, and
    # watchOS 10 ships the Swift runtime, so nothing needs embedding.
    %w[ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME
       ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES].each { |k| c.build_settings.delete(k) }
  end
  # new_target links Foundation by an SDK-VERSIONED path
  # (WatchOS26.0.sdk/...), which breaks on any other Xcode. Swift autolinks
  # every framework these targets import, so drop the explicit link.
  target.frameworks_build_phase.files.dup.each do |bf|
    ref = bf.file_ref
    bf.remove_from_project
    ref.remove_from_project if ref && ref.referrers.none? { |r| r.is_a?(Xcodeproj::Project::Object::PBXBuildFile) }
  end
end

common = {
  'SDKROOT' => 'watchos',
  # Flutter's PROJECT-level Release/Profile configs pin SUPPORTED_PLATFORMS =
  # iphoneos, which these targets would inherit — and Xcode then compiles the
  # widget extension against the iOS SDK ("'accessoryCorner' is unavailable in
  # iOS"). Measured on the first Mac build, 2026-11-10.
  'SUPPORTED_PLATFORMS' => 'watchos watchsimulator',
  'WATCHOS_DEPLOYMENT_TARGET' => WATCHOS,
  'TARGETED_DEVICE_FAMILY' => '4',
  'SWIFT_VERSION' => '5.0',
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => TEAM,
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'SKIP_INSTALL' => 'YES',
  'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
  'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
  'SWIFT_EMIT_LOC_STRINGS' => 'YES',
  'ENABLE_PREVIEWS' => 'YES',
}

# ── Watch app ──────────────────────────────────────────────────────────────
watch = proj.new_target(:application, 'CanopyWatch', :watchos, WATCHOS,
                        proj.products_group, :swift)
configure(watch, watch_xcconfig, common.merge(
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.danjjohnson.canopy.watchkitapp',
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => 'CanopyWatch/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Canopy',
  'INFOPLIST_KEY_WKCompanionAppBundleIdentifier' => 'com.danjjohnson.canopy',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations' =>
    'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown',
  'CODE_SIGN_ENTITLEMENTS' => 'CanopyWatch/CanopyWatch.entitlements',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
))

# ── Widget extension (complications) ──────────────────────────────────────
widgets = proj.new_target(:app_extension, 'CanopyWatchWidgets', :watchos, WATCHOS,
                          proj.products_group, :swift)
configure(widgets, watch_xcconfig, common.merge(
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.danjjohnson.canopy.watchkitapp.widgets',
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => 'CanopyWatchWidgets/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Canopy',
  'CODE_SIGN_ENTITLEMENTS' => 'CanopyWatchWidgets/CanopyWatchWidgets.entitlements',
  'APPLICATION_EXTENSION_API_ONLY' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' =>
    '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
))

# ── Sources ────────────────────────────────────────────────────────────────
shared = group_for(proj, 'CanopyWatchShared')
shared_ref = shared.new_reference('WristTimeline.swift')
watch.add_file_references([shared_ref])
widgets.add_file_references([shared_ref])

wg = group_for(proj, 'CanopyWatch')
watch.add_file_references(%w[CanopyWatchApp.swift NowView.swift Buzz.swift].map { |f| wg.new_reference(f) })
watch.add_resources([wg.new_reference('Assets.xcassets')])
%w[Info.plist CanopyWatch.entitlements].each { |f| wg.new_reference(f) }

xg = group_for(proj, 'CanopyWatchWidgets')
widgets.add_file_references(%w[CanopyComplication.swift].map { |f| xg.new_reference(f) })
%w[Info.plist CanopyWatchWidgets.entitlements].each { |f| xg.new_reference(f) }

rg = proj.main_group.find_subpath('Runner', false)
runner.add_file_references([rg.new_reference('WatchBridge.swift')])

# ── Embedding ──────────────────────────────────────────────────────────────
# Extension → watch app's PlugIns.
watch.add_dependency(widgets)
ext = watch.new_copy_files_build_phase('Embed Foundation Extensions')
ext.dst_subfolder_spec = '13'
ext.add_file_reference(widgets.product_reference)
   .settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Watch app → Runner.app/Watch. Placed right after "Embed Frameworks" and
# BEFORE Flutter's "Thin Binary" script: after it, Xcode reports a build
# phase cycle (a known Flutter + watch/extension pitfall).
runner.add_dependency(watch)
emb = runner.new_copy_files_build_phase('Embed Watch Content')
emb.dst_subfolder_spec = '16'
emb.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
emb.add_file_reference(watch.product_reference)
   .settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
runner.build_phases.delete(emb)
thin = runner.build_phases.index { |p| p.display_name == 'Thin Binary' }
runner.build_phases.insert(thin, emb)

# new_target also leaves an (now empty) Frameworks/watchOS group behind.
empty = proj.frameworks_group.children.find { |c| c.display_name == 'watchOS' }
empty.remove_from_project if empty && empty.children.empty?

proj.save
puts 'Added CanopyWatch + CanopyWatchWidgets.'
