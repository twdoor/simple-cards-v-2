#!/usr/bin/env python3
"""Isolated Godot compiler-retention probe; intentionally emits a shutdown warning.

Based on the behavior described at https://github.com/godotengine/godot/issues/122022.
No addon scripts, scenes, animations, or autoloads are loaded.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

engine = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')
if not engine:
    raise SystemExit('Set GODOT to an editor binary.')
files = {
    'project.godot': 'config_version=5\n',
    'token.gd': 'class_name RetainedToken extends RefCounted\nstatic func allocate() -> RetainedToken:\n\treturn RetainedToken.new()\n',
    'base.gd': 'class_name RetentionBase extends RefCounted\n',
    'derived.gd': 'class_name RetentionDerived extends RetentionBase\nstatic func allocate() -> RetentionDerived:\n\treturn RetentionDerived.new()\n',
    'factory.gd': 'extends Node\nfunc allocate() -> RetentionBase:\n\treturn RetentionDerived.new()\n',
    'probe.gd': 'extends SceneTree\nconst FACTORY = preload("res://factory.gd")\nfunc _initialize() -> void:\n\tvar token = RetainedToken.new()\n\tprint(token != null and FACTORY != null)\n\tquit()\n',
}
with tempfile.TemporaryDirectory(prefix='godot-retention-') as directory:
    for name, text in files.items():
        (Path(directory) / name).write_text(text)
    subprocess.run([engine, '--headless', '--path', directory, '--editor', '--import'], check=True, timeout=30)
    subprocess.run([engine, '--headless', '--verbose', '--path', directory, '--script', 'probe.gd'], check=True, timeout=15)
