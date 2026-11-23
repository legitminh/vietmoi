#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; shared source files stay in Sources/."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
ios = root / 'iOS'
project = ios / 'VietMobile.xcodeproj'
project.mkdir(exist_ok=True)
existing = project / 'project.pbxproj'
teams = set(re.findall(r'\bDEVELOPMENT_TEAM\s*=\s*"?([A-Z0-9]{10})"?;', existing.read_text())) if existing.exists() else set()
selected_team = next(iter(teams)) if len(teams) == 1 else None
release = json.loads((root / 'Design/brand.json').read_text())
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(value, ensure_ascii=False)
def arr(values): return '(' + ', '.join(values) + (',' if values else '') + ')'
def obj(name, isa, body):
    objects[ident(name)] = f'{{ isa = {isa}; {body} }}'
    return ident(name)
def file(name, path, kind):
    return obj('file.'+name, 'PBXFileReference', f'lastKnownFileType = {kind}; path = {q(path)}; sourceTree = "<group>";')
def group(name, children, path=None):
    return obj('group.'+name, 'PBXGroup', f'children = {arr(children)}; name = {q(name)}; ' + (f'path = {q(path)}; ' if path else '') + 'sourceTree = "<group>";')
def configs(name, extra):
    refs = []
    common = {'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'16.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','CLANG_ENABLE_MODULES':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES','MARKETING_VERSION':release['version'],'CURRENT_PROJECT_VERSION':str(release['build']),'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO'}
    if selected_team: common['DEVELOPMENT_TEAM'] = selected_team
    for config in ['Debug','Release']:
        values = {**common, 'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT':'dwarf' if config == 'Debug' else 'dwarf-with-dsym', **extra}
        if config == 'Debug': values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        settings = ' '.join(f'{k} = {q(v)};' for k,v in values.items())
        refs.append(obj(name+'.'+config,'XCBuildConfiguration',f'buildSettings = {{ {settings} }}; name = {config};'))
    return obj(name+'.configs','XCConfigurationList',f'buildConfigurations = {arr(refs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
core = [file('core.'+p.name,p.name,'sourcecode.swift') for p in sorted((root/'Sources/Core').glob('*.swift')) if p.name != 'KeyboardPreferences.swift']
presentation = [file('presentation.'+p.name,p.name,'sourcecode.swift') for p in sorted((root/'Sources/Presentation').glob('*.swift'))]
mobile = [file('mobile.'+p.name,p.name,'sourcecode.swift') for p in sorted((root/'Sources/Mobile').glob('*.swift'))]
app = [file('app.'+p.name,p.name,'sourcecode.swift') for p in sorted((ios/'App').glob('*.swift'))]
ext = [file('extension.'+p.name,p.name,'sourcecode.swift') for p in sorted((ios/'KeyboardExtension').glob('*.swift'))]
tests = [file('tests.'+p.name,p.name,'sourcecode.swift') for p in sorted((ios/'UITests').glob('*.swift'))]
privacy = file('privacy','PrivacyInfo.xcprivacy','text.xml')
assets = file('assets','Assets.xcassets','folder.assetcatalog')
chinese = file('chinese','../Resources/Chinese','folder')
app_info = file('app.plist','Info.plist','text.plist.xml')
ext_info = file('ext.plist','Info.plist','text.plist.xml')
app_entitlements = file('app.entitlements','Settings.entitlements','text.plist.entitlements')
ext_entitlements = file('ext.entitlements','Settings.entitlements','text.plist.entitlements')
products = {}
for name, suffix, kind in [('VietMobile','app','wrapper.application'),('VietKeyboard','appex','wrapper.app-extension'),('VietMobileUITests','xctest','wrapper.cfbundle')]:
    products[name] = obj('product.'+name,'PBXFileReference',f'explicitFileType = {kind}; path = {name}.{suffix}; sourceTree = BUILT_PRODUCTS_DIR;')
def phase(name, isa, files, extra=''):
    builds = [obj(name+'.build.'+ref,'PBXBuildFile',f'fileRef = {ref};') for ref in files]
    return obj(name,isa,f'buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0; {extra}')
project_id = ident('project')
def dependency(source,target):
    proxy=obj('proxy.'+source+target,'PBXContainerItemProxy',f'containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {ident("target."+target)}; remoteInfo = {target};')
    return obj('dependency.'+source+target,'PBXTargetDependency',f'target = {ident("target."+target)}; targetProxy = {proxy};')
embed_build = obj('embed.extension.build','PBXBuildFile',f'fileRef = {products["VietKeyboard"]}; settings = {{ ATTRIBUTES = (RemoveHeadersOnCopy, CodeSignOnCopy,); }};')
embed = obj('embed.extension','PBXCopyFilesBuildPhase',f'buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({embed_build},); name = "Embed Keyboard Extension"; runOnlyForDeploymentPostprocessing = 0;')
settings = {
'VietMobile': {'PRODUCT_BUNDLE_IDENTIFIER':'com.minh.sieuviet.ios','PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'App/Info.plist','CODE_SIGN_ENTITLEMENTS':'App/Settings.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'},
'VietKeyboard': {'PRODUCT_BUNDLE_IDENTIFIER':'com.minh.sieuviet.ios.keyboard','PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'KeyboardExtension/Info.plist','CODE_SIGN_ENTITLEMENTS':'KeyboardExtension/Settings.entitlements','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'},
'VietMobileUITests': {'PRODUCT_BUNDLE_IDENTIFIER':'com.minh.sieuviet.ios.uitests','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TEST_TARGET_NAME':'VietMobile'}
}
target_ids=[]
for name, sources, resources, product_type in [('VietMobile',core+presentation+mobile+app,[privacy,assets,chinese],'application'),('VietKeyboard',core+presentation+mobile+ext,[privacy,chinese],'app-extension'),('VietMobileUITests',tests,[],'bundle.ui-testing')]:
    phases=[phase(name+'.sources','PBXSourcesBuildPhase',sources),phase(name+'.frameworks','PBXFrameworksBuildPhase',[]),phase(name+'.resources','PBXResourcesBuildPhase',resources)]
    deps=[]
    if name=='VietMobile': phases.append(embed); deps.append(dependency(name,'VietKeyboard'))
    if name=='VietMobileUITests': deps.append(dependency(name,'VietMobile'))
    target_ids.append(obj('target.'+name,'PBXNativeTarget',f'buildConfigurationList = {configs(name,settings[name])}; buildPhases = {arr(phases)}; buildRules = (); dependencies = {arr(deps)}; name = {name}; productName = {name}; productReference = {products[name]}; productType = "com.apple.product-type.{product_type}";'))
main=group('Root',[group('Core',core,'../Sources/Core'),group('Presentation',presentation,'../Sources/Presentation'),group('Mobile',mobile,'../Sources/Mobile'),group('App',app+[app_info,app_entitlements],'App'),group('KeyboardExtension',ext+[ext_info,ext_entitlements],'KeyboardExtension'),group('UITests',tests,'UITests'),privacy,assets,chinese,group('Products',list(products.values()))])
capabilities = ' '.join(f'{ident("target."+name)} = {{ ProvisioningStyle = Automatic; SystemCapabilities = {{ com.apple.ApplicationGroups.iOS = {{ enabled = 1; }}; }}; }};' for name in ['VietMobile','VietKeyboard'])
obj('project','PBXProject',f'attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {capabilities} }}; }}; buildConfigurationList = {configs("Project",{})}; compatibilityVersion = "Xcode 14.0"; developmentRegion = vi; hasScannedForEncodings = 0; knownRegions = (en, Base, vi,); mainGroup = {main}; productRefGroup = {ident("group.Products")}; projectDirPath = ""; projectRoot = ""; targets = {arr(target_ids)};')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(f'{k} = {v};' for k,v in objects.items()) + f'\n}}; rootObject = {project_id}; }}\n')
schemes = project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target."+name)}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:VietMobile.xcodeproj"/>'
(schemes/'VietMobile.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('VietMobile')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('VietMobileUITests').replace('.app', '.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('VietMobile')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugServiceExtension="internal"><BuildableProductRunnable runnableDebuggingMode="0">{ref('VietMobile')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(project)
