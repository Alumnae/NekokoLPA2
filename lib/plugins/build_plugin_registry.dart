// GENERATED FILE - DO NOT EDIT
// Run `dart run scripts/generate_plugin_registry.dart` to update.

import 'bee_sim_plugin.dart';
import 'estk_plugin.dart';
import 'gm_plugin.dart';
import 'nekoko_stats_plugin.dart';
import 'plugin_base.dart';
import 'session_plugin.dart';

typedef ProfilePluginFactory = ProfilePlugin Function();
typedef SessionPluginFactory = SessionPlugin Function();

class BuildPluginRegistry {
  BuildPluginRegistry._();

  static final Map<String, ProfilePluginFactory> _profileFactories =
      <String, ProfilePluginFactory>{
        'NekokoStatsPlugin': NekokoStatsPlugin.new,
        'EstkPlugin': EstkPlugin.new,
        'BeeSimPlugin': BeeSimPlugin.new,
      };

  static final Map<String, SessionPluginFactory> _sessionFactories =
      <String, SessionPluginFactory>{
        'GmPlugin': GmPlugin.new,
        'EstkPlugin': EstkPlugin.new,
      };

  static List<ProfilePlugin> createPlugins() {
    return _profileFactories.values.map((factory) => factory()).toList(growable: false);
  }

  static List<SessionPlugin> createSessionPlugins() {
    return _sessionFactories.values.map((factory) => factory()).toList(growable: false);
  }
}
