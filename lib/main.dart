import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_launcher_icons/android.dart' as android_launcher_icons;
import 'package:flutter_launcher_icons/ios.dart' as ios_launcher_icons;
import 'package:flutter_launcher_icons/custom_exceptions.dart';
import 'package:flutter_launcher_icons/constants.dart';

const String fileOption = "file";
const String helpFlag = "help";
const String defaultConfigFile = "flutter_launcher_icons.yaml";
const String flavorConfigFilePattern = "\./flutter_launcher_icons-(.*).yaml";

String flavorConfigFile(String flavor) => "flutter_launcher_icons-$flavor.yaml";

List<String> getFlavors() {
  List<String> flavors = [];
  for (var item in Directory('.').listSync()) {
    if (item is File) {
      var match = RegExp(flavorConfigFilePattern).firstMatch(item.path);
      if (match != null) {
        flavors.add(match.group(1));
      }
    }
  }
  return flavors;
}

void createIconsFromArguments(List<String> arguments) async {
  var parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag("help", abbr: "h", help: "Usage help", negatable: false);
  // Make default null to differentiate when it is explicitly set
  parser.addOption(fileOption,
      abbr: "f", help: "Config file (default: $defaultConfigFile)");
  var argResults = parser.parse(arguments);

  if (argResults[helpFlag]) {
    stdout.writeln('Generates icons for iOS and Android');
    stdout.writeln(parser.usage);
    exit(0);
  }

  // Flavors manangement
  var flavors = getFlavors();
  var hasFlavors = flavors.isNotEmpty;

  // Load the config file
  var yamlConfig =
      await loadConfigFileFromArgResults(argResults, verbose: true);

  // Create icons
  if (!hasFlavors) {
    if ((yamlConfig == null) || (!(yamlConfig["flutter_icons"] is Map))) {
      stderr.writeln(NoConfigFoundException(
          'Check that your config file `${argResults[fileOption] ?? defaultConfigFile}` has a `flutter_icons` section'));
      exit(1);
    }

    try {
      await createIconsFromConfig(yamlConfig);
    } catch (e) {
      stderr.writeln(e);
      exit(2);
    }
  } else {
    try {
      if ((yamlConfig != null) && (yamlConfig["flutter_icons"] is Map)) {
        await createIconsFromConfig(yamlConfig);
      }

      for (var flavor in flavors) {
        yamlConfig = await loadConfigFile(flavorConfigFile(flavor));
        await createIconsFromConfig(yamlConfig, flavor);
      }
    } catch (e) {
      stderr.writeln(e);
      exit(2);
    }
  }
}

void createIconsFromConfig(Map yamlConfig, [String flavor]) async {
  Map config = loadFlutterIconsConfig(yamlConfig);
  if (!isImagePathInConfig(config)) {
    throw InvalidConfigException(errorMissingImagePath);
  }
  if (!hasAndroidOrIOSConfig(config)) {
    throw InvalidConfigException(errorMissingPlatform);
  }
  var minSdk = android_launcher_icons.minSdk();
  if (minSdk < 26 &&
      hasAndroidAdaptiveConfig(config) &&
      !hasAndroidConfig(config)) {
    throw InvalidConfigException(errorMissingRegularAndroid);
  }

  if (isNeedingNewAndroidIcon(config)) {
    android_launcher_icons.createDefaultIcons(config, flavor);
  }
  if (hasAndroidAdaptiveConfig(config)) {
    android_launcher_icons.createAdaptiveIcons(config, flavor);
  }
  if (isNeedingNewIOSIcon(config)) {
    ios_launcher_icons.createIcons(config, flavor);
  }
}

Map loadConfigFileFromArgResults(ArgResults argResults,
    {bool verbose}) {
  verbose ??= false;
  String configFile = argResults[fileOption];

  Map yamlConfig;
  // If none set try flutter_launcher_icons.yaml first then pubspec.yaml
  // for compatibility
  if (configFile == defaultConfigFile || configFile == null) {
    try {
      yamlConfig = loadConfigFile(defaultConfigFile);
    } catch (e) {
      if (configFile == null) {
        try {
          // Try pubspec.yaml for compatibility
          yamlConfig = loadConfigFile("pubspec.yaml");
        } catch (_) {
          if (verbose) {
            stderr.writeln(e);
          }
        }
      } else {
        if (verbose) {
          stderr.writeln(e);
        }
      }
    }
  } else {
    try {
      yamlConfig = loadConfigFile(configFile);
    } catch (e) {
      if (verbose) {
        stderr.writeln(e);
      }
    }
  }
  return yamlConfig;
}

Map loadConfigFile(String path) {
  File file = File(path);
  String yamlString = file.readAsStringSync();
  Map config = loadYaml(yamlString);
  return config;
}

Map loadFlutterIconsConfig(Map config) {
  return config["flutter_icons"];
}

bool isImagePathInConfig(Map flutterIconsConfig) {
  return flutterIconsConfig.containsKey("image_path") ||
      (flutterIconsConfig.containsKey("image_path_android") &&
          flutterIconsConfig.containsKey("image_path_ios"));
}

bool hasAndroidOrIOSConfig(Map flutterIconsConfig) {
  return flutterIconsConfig.containsKey("android") ||
      flutterIconsConfig.containsKey("ios");
}

bool hasAndroidConfig(Map flutterLauncherIcons) {
  return flutterLauncherIcons.containsKey("android");
}

bool isNeedingNewAndroidIcon(Map flutterLauncherIconsConfig) {
  if (hasAndroidConfig(flutterLauncherIconsConfig)) {
    if (flutterLauncherIconsConfig['android'] != false) {
      return true;
    }
  }
  return false;
}

bool hasAndroidAdaptiveConfig(Map flutterLauncherIconsConfig) {
  return isNeedingNewAndroidIcon(flutterLauncherIconsConfig) &&
      flutterLauncherIconsConfig.containsKey("adaptive_icon_background") &&
      flutterLauncherIconsConfig.containsKey("adaptive_icon_foreground");
}

bool hasIOSConfig(Map flutterLauncherIconsConfig) {
  return flutterLauncherIconsConfig.containsKey("ios");
}

bool isNeedingNewIOSIcon(Map flutterLauncherIconsConfig) {
  if (hasIOSConfig(flutterLauncherIconsConfig)) {
    if (flutterLauncherIconsConfig["ios"] != false) {
      return true;
    }
  }
  return false;
}
