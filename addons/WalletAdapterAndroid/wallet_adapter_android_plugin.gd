@tool
extends EditorPlugin

var export_plugin: AndroidExportPlugin

func _enter_tree():
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = "WalletAdapterAndroid"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug):
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray([_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"])

	func _get_android_dependencies(platform, debug):
		return PackedStringArray([
			"com.solanamobile:mobile-wallet-adapter-clientlib-ktx:2.0.3",
			"com.solanamobile:rpc-core:0.2.8",
			"com.solanamobile:rpc-solana:0.2.8",
			"com.solanamobile:rpc-ktordriver:0.2.8",
			"androidx.compose.ui:ui:1.4.3",
			"androidx.compose.material:material:1.4.3",
			"androidx.compose.ui:ui-tooling-preview:1.4.3",
			"androidx.activity:activity-compose:1.8.0",
		])

	func _get_name():
		return _plugin_name
