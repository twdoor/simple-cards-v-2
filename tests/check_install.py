#!/usr/bin/env python3
"""Build an addon-only fixture and exercise its exported resource pack."""
import os
import json
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ENGINE = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')


PROBE_SCRIPT = '''@tool
extends EditorPlugin
var failed := false
func _enter_tree() -> void:
	_run.call_deferred()
func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _run() -> void:
	EditorInterface.set_plugin_enabled("simple_cards", false)
	_expect(not ProjectSettings.has_setting("autoload/CG"), "Disable retained CG autoload.")
	EditorInterface.set_plugin_enabled("simple_cards", true)
	_expect(ProjectSettings.get_setting("autoload/CG", "") == "*res://addons/simple_cards/card_global.gd", "Re-enable did not restore CG.")
	var cache := LayoutCache.new()
	cache.sync_cache()
	_expect(cache.has_layout(&"fixture_front"), "Custom layout missing from editor cache.")
	cache.set_layout_enabled("res://front.tscn", false)
	_expect(not cache.has_layout(&"fixture_front"), "Disabled layout remained enabled.")
	cache.set_layout_enabled("res://front.tscn", true)
	# Exercise actual @tool nodes through their inspector properties and tree lifecycle.
	var card := Card.new()
	card.front_layout_name = &"fixture_front"
	add_child(card)
	_expect(card.get_layout() != null and card.size.x > 0, "Standalone card preview missing.")
	var old_layout := weakref(card.get_layout())
	card.front_layout_name = &"fixture_back"
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(old_layout.get_ref() == null and card.get_layout() != null, "Layout replacement retained the old preview.")
	remove_child(card)
	await get_tree().process_frame
	await get_tree().process_frame
	add_child(card)
	_expect(card.get_layout() != null, "Card preview did not recover after tree re-entry.")
	var pile := CardPile.new()
	pile.preview_layout_name = &"fixture_front"
	pile.preview_card_count = 3
	pile.preview_enabled = true
	add_child(pile)
	await get_tree().process_frame
	_expect(pile.get_child_count(true) == 3 and pile.get_card_count() == 0, "Preview cards entered runtime membership or count is wrong.")
	_expect(pile.get_minimum_size().x > 0, "Preview bounds are empty.")
	pile.preview_card_count = 1
	pile.preview_layout_name = &"fixture_back"
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(pile.get_child_count(true) == 1, "Preview count change did not free excess cards.")
	pile.preview_enabled = false
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(pile.get_child_count(true) == 0, "Disabling preview retained visual cards.")
	pile.preview_enabled = true
	remove_child(pile)
	await get_tree().process_frame
	await get_tree().process_frame
	add_child(pile)
	_expect(pile.get_child_count(true) == 1, "Container preview did not recover after tree re-entry.")
	card.queue_free()
	pile.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(DirAccess.rename_absolute("res://front.tscn", "res://renamed_front.tscn") == OK, "Layout rename failed.")
	cache.sync_cache()
	_expect(cache.get_layout_path(&"fixture_front") == "res://renamed_front.tscn", "Cache retained old layout path.")
	_expect(cache.set_layout_id("res://renamed_front.tscn", "renamed_fixture"), "Layout ID rename failed.")
	_expect(cache.has_layout(&"renamed_fixture") and not cache.has_layout(&"fixture_front"), "Layout ID cache was not refreshed.")
	_expect(cache.delete_layout("res://renamed_front.tscn"), "Layout deletion failed.")
	_expect(not cache.has_layout(&"renamed_fixture"), "Deleted layout remained cached.")
	_expect(cache.has_layout(LayoutID.DEFAULT) and cache.has_layout(LayoutID.DEFAULT_BACK), "Default fallbacks were lost.")
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	print("Editor lifecycle/cache fixture passed." if not failed else "Editor fixture failed.")
	get_tree().quit(1 if failed else 0)
'''

def main():
    if not ENGINE:
        raise RuntimeError('Set GODOT to the editor executable.')
    with tempfile.TemporaryDirectory(prefix='cards-install-') as folder:
        project = Path(folder)
        shutil.copytree(ROOT / 'addons', project / 'addons')
        (project / 'project.godot').write_text('''config_version=5
[application]
config/name="Simple Cards installation test"
run/main_scene="res://main.tscn"
[editor_plugins]
enabled=PackedStringArray("res://addons/simple_cards/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
''')
        # These layout IDs are discovered by the editor, not preloaded by the fixture.
        for face in ['front', 'back']:
            original = ROOT / 'addons/simple_cards/card/card_layout/default_card_layout.tscn'
            content = original.read_text()
            content = re.sub(r' uid="[^"]+"', '', content)
            content = content.replace('[node name="CardLayout" type="SubViewportContainer"]', '[node name="CardLayout" type="SubViewportContainer"]\nmetadata/is_layout = true\nmetadata/layout_id = "fixture_' + face + '"')
            (project / f'{face}.tscn').write_text(content)
        (project / 'fixture_card.gd').write_text('''extends CardResource
@export var title: String = "Installed"
''')
        (project / 'main.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://main.gd" id="1"]
[node name="InstallTest" type="Node"]
script = ExtResource("1")
''')
        (project / 'main.gd').write_text('''extends Node
func _ready() -> void:
\tvar data = preload("res://fixture_card.gd").new()
\tdata.front_layout_name = &"fixture_front"
\tdata.back_layout_name = &"fixture_back"
\tvar a := CardPile.new()
\tvar b := CardPile.new()
\ta.face_up = true
\tb.face_up = false
\tadd_child(a)
\tadd_child(b)
\tvar card := Card.new(data)
\tcard.move_to(a, Card.MoveConfig.new(0.0))
\tif not CG.has_layout(&"fixture_front") or card.current_layout_name != &"fixture_front":
\t\tpush_error("Custom front layout missing from installation/export.")
\t\tget_tree().quit(1)
\t\treturn
\tcard.move_to(b, Card.MoveConfig.new(0.0))
\tawait get_tree().create_timer(0.3).timeout
\tif not a.is_empty() or b.get_card_count() != 1 or card.current_layout_name != &"fixture_back":
\t\tpush_error("Transfer or custom back layout failed.")
\t\tget_tree().quit(1)
\t\treturn
\ta.queue_free()
\tb.queue_free()
\tawait get_tree().process_frame
\tprint("Installation/export fixture passed.")
\tget_tree().quit()
''')
        (project / 'export_presets.cfg').write_text('''[preset.0]
name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="fixture.pck"
[preset.0.options]
binary_format/architecture="x86_64"
''')
        native_template = os.environ.get('GODOT_LINUX_TEMPLATE')
        if native_template:
            with (project / 'export_presets.cfg').open('a') as preset:
                preset.write('custom_template/debug=' + json.dumps(str(Path(native_template).resolve())) + '\n')

        def run(label, args):
            result = subprocess.run([ENGINE, '--headless', '--path', folder, *args], capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            print(f'{label}:\n{output}', flush=True)
            if result.returncode or 'ERROR:' in output or 'ObjectDB instances leaked' in output:
                raise RuntimeError(f'{label} failed')
        run('Import addon only', ['--editor', '--import'])
        run('Installed project', [])
        run('Export pack', ['--editor', '--export-pack', 'Linux', str(project / 'fixture.pck')])
        # Run outside the source project so missing source files cannot mask omissions.
        with tempfile.TemporaryDirectory(prefix='cards-export-run-') as isolated:
            pack = Path(isolated) / 'fixture.pck'
            shutil.copy2(project / 'fixture.pck', pack)
            result = subprocess.run([ENGINE, '--headless', '--path', isolated, '--main-pack', str(pack)], capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            print(output)
            if result.returncode or 'ERROR:' in output or 'ObjectDB instances leaked' in output or 'Installation/export fixture passed.' not in output:
                raise RuntimeError('Exported pack failed')
        if native_template:
            with tempfile.TemporaryDirectory(prefix='cards-native-export-') as isolated:
                executable = Path(isolated) / 'fixture.x86_64'
                run('Export native Linux executable', ['--editor', '--export-debug', 'Linux', str(executable)])
                result = subprocess.run([str(executable), '--headless'], cwd=isolated,
                                        capture_output=True, text=True, timeout=20)
                output = result.stdout + result.stderr
                print(output)
                if result.returncode or 'ERROR:' in output or 'ObjectDB instances leaked' in output or 'Installation/export fixture passed.' not in output:
                    raise RuntimeError('Native exported executable failed')
                print('PASS native Linux export')
        # Exercise actual editor plugin toggles and cache maintenance in isolation.
        probe_dir = project / 'addons/install_probe'
        probe_dir.mkdir()
        (probe_dir / 'plugin.cfg').write_text('[plugin]\nname="InstallProbe"\ndescription="Test"\nauthor="Test"\nversion="1"\nscript="probe.gd"\n')
        (probe_dir / 'probe.gd').write_text(PROBE_SCRIPT)
        config = (project / 'project.godot').read_text()
        config = config.replace('PackedStringArray("res://addons/simple_cards/plugin.cfg")',
                                'PackedStringArray("res://addons/simple_cards/plugin.cfg", "res://addons/install_probe/plugin.cfg")')
        (project / 'project.godot').write_text(config)
        run('Editor enable/disable and cache maintenance', ['--editor'])
        print('PASS addon-only installation and isolated exported pack')


if __name__ == '__main__':
    main()
