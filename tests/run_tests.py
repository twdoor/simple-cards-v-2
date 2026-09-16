#!/usr/bin/env python3
"""Bounded Godot validation, runnable from any working directory."""
import argparse
import os
import re
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')
LOGS = Path(os.environ.get('TEST_LOG_DIR') or tempfile.mkdtemp(prefix='simple-cards-tests-')).resolve()
LOGS.mkdir(parents=True, exist_ok=True)


# Godot 4.5.x compiler retention, independently reproduced without addon code.
# Keep this exact: a new script path, instance type, or count must fail validation.
SCRIPT_RETENTION_PATHS = {
    'res://addons/simple_cards/' + path for path in [
        'card_global.gd', 'card/card.gd', 'network/card_network_manager.gd',
        'card/card_layout/card_layout.gd', 'card/card_resource/card_resource.gd',
        'layout_ids.gd', 'containers/card_container.gd',
        'card/card_layout/card_animation_resource/card_animation_resource.gd',
        'shape/card_container_shape.gd', 'containers/pile/card_pile.gd',
        'containers/slot/card_slot.gd',
    ]
}


def known_script_retention(name, output):
    if os.environ.get('STRICT_ENGINE_LEAKS') == '1':
        return False
    if name not in {'import', 'CoreRegressionTest', 'ExampleSmokeTest', 'rendered-balatro', 'rendered-solitaire'}:
        return False
    if not re.search(r'Godot Engine v4\.5\.[12]\.stable', output):
        return False
    paths = re.findall(r'^Resource still in use: (.+) \(GDScript\)$', output, re.M)
    instances = re.findall(r'^Leaked instance: ([^:]+):', output, re.M)
    return (set(paths) == SCRIPT_RETENTION_PATHS and len(paths) == 11
            and len(instances) == 23 and instances.count('GDScript') == 13
            and instances.count('GDScriptNativeClass') == 10
            and output.count('ERROR: 11 resources still in use at exit.') == 1)


def check(name, code):
    output = (LOGS / f'{name}.log').read_text(errors='replace')
    known = known_script_retention(name, output)
    if known:
        output = output.replace('ERROR: 11 resources still in use at exit.', '')
        output = output.replace('WARNING: ObjectDB instances leaked at exit (run with --verbose for details).', '')
    errors = ('SCRIPT ERROR:', 'ERROR:', 'ObjectDB instances leaked')
    if code or any(marker in output for marker in errors):
        raise RuntimeError(f'{name} failed (exit {code}):\n{output}')
    completion = {
        'CoreRegressionTest': 'Core regression tests passed.',
        'rendered-balatro': 'Rendered balatro gameplay passed.',
        'rendered-solitaire': 'Rendered solitaire gameplay passed.',
        'MultiplayerRegressionTest': 'Multiplayer regression tests passed.',
        'ExampleSmokeTest': 'Example teardown checks passed.',
        'client': 'Client roundtrip passed',
        'server': 'Server roundtrip passed.',
        'installation': 'PASS addon-only installation and isolated exported pack',
    }.get(name)
    if completion and completion not in output:
        raise RuntimeError(f'{name} exited without completing its assertions')
    if name == 'snapshot-benchmark' and output.count('SNAPSHOT cards=') != 4:
        raise RuntimeError('Snapshot benchmark did not complete all four cases')
    suffix = ' (known Godot script-retention diagnostic; see log)' if known else ''
    print(f'PASS {name}{suffix}', flush=True)


def run(name, args, timeout=60):
    with (LOGS / f'{name}.log').open('w') as log:
        result = subprocess.run([ENGINE, '--headless', '--verbose', '--path', str(ROOT), *args],
                                stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    check(name, result.returncode)


def roundtrip():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = os.environ.get('TEST_PORT', str(sock.getsockname()[1]))
    args = [ENGINE, '--headless', '--path', str(ROOT), '--scene',
            'res://tests/ServerRoundtripTest.tscn', '--', f'--port={port}']
    with (LOGS / 'server.log').open('w') as log:
        server = subprocess.Popen([*args, '--role=server'], stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 10
            while 'ROUNDTRIP_READY' not in (LOGS / 'server.log').read_text():
                if server.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError('Server did not become ready; see server.log')
                time.sleep(0.05)
            run('client', ['--scene', 'res://tests/ServerRoundtripTest.tscn', '--',
                           '--role=client', f'--port={port}'], timeout=20)
            check('server', server.wait(timeout=15))
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()


def macau(players, rendered=False):
    processes = []
    logs = []
    try:
        for index in range(players):
            name = f'macau-{players}-{index}'
            log = (LOGS / f'{name}.log').open('w')
            logs.append(log)
            args = [ENGINE, '--verbose', *(['--display-driver', 'x11', '--audio-driver', 'Dummy'] if rendered else ['--headless']), '--path', str(ROOT), '--scene',
                    'res://tests/MacauIntegrationTest.tscn', '--',
                    f'--players={players}', '--role=' + ('server' if index == 0 else 'client')]
            if rendered:
                args.append('--gameplay')
            if rendered and index < 2:
                screenshot = LOGS / f'{name}.png'
                args.append(f'--screenshot={screenshot}')
            process = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
            processes.append((name, process))
            if index == 0:
                deadline = time.monotonic() + 10
                while 'MACAU_READY' not in (LOGS / f'{name}.log').read_text():
                    if process.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError(f'{name} did not start')
                    time.sleep(0.05)
        deadline = time.monotonic() + (75 if rendered else 30)
        for name, process in processes:
            check(name, process.wait(timeout=max(0.1, deadline - time.monotonic())))
            if rendered and name.endswith('-0') and 'Macau rendered gameplay passed.' not in (LOGS / f'{name}.log').read_text():
                raise RuntimeError(f'{name} did not complete gameplay checks')
            if 'passed.' not in (LOGS / f'{name}.log').read_text():
                raise RuntimeError(f'{name} exited without reaching its assertions')
    finally:
        for _, process in processes:
            if process.poll() is None:
                process.kill()
            process.wait()
        for log in logs:
            log.close()


def main():
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--roundtrip-only', action='store_true')
    parser.add_argument('--rendered-only', action='store_true', help='Run viewport input and multiplayer gameplay checks; requires a display.')
    opts = parser.parse_args()
    if not ENGINE:
        raise RuntimeError('Set GODOT to the Godot editor executable or install godot on PATH.')
    if opts.rendered_only and not os.environ.get('DISPLAY'):
        raise RuntimeError('Rendered validation requires an X11 display. Run with xvfb-run -a; validation does not install system packages.')
    print(f'Logs: {LOGS}', flush=True)
    # Isolate generated caches and editor state, including on a developer checkout.
    with tempfile.TemporaryDirectory(prefix='simple-cards-work-') as work:
        shutil.copytree(ROOT, work, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('.git', '.godot', '.releases', '__pycache__'))
        ROOT = Path(work)
        run('import', ['--editor', '--import'], timeout=120)
        if opts.rendered_only:
            for example in ['balatro', 'solitaire']:
                name = f'rendered-{example}'
                try:
                    with (LOGS / f'{name}.log').open('w') as log:
                        result = subprocess.run([ENGINE, '--verbose', '--display-driver', 'x11',
                                                 '--audio-driver', 'Dummy',
                                                 '--path', str(ROOT), '--scene',
                                                 'res://tests/RenderedGameplayTest.tscn', '--', example,
                                                 str(LOGS / f'{example}.png')], stdout=log,
                                                stderr=subprocess.STDOUT, timeout=75)
                finally:
                    # A timed-out drag must not leave the display's mouse button held.
                    subprocess.run([sys.executable, str(ROOT / 'tests/native_mouse.py'), '0'],
                                   check=True, timeout=5)
                check(name, result.returncode)
            macau(2, rendered=True)
            macau(6, rendered=True)
            return
        if not opts.roundtrip_only:
            for name in ['CoreRegressionTest', 'MultiplayerRegressionTest']:
                run(name, ['--scene', f'res://tests/{name}.tscn'])
            run('ExampleSmokeTest', ['--scene', 'res://tests/ExampleSmokeTest.tscn', '--',
                                    'res://examples/balatro/BalatroExample.tscn',
                                    'res://examples/solitaire/SolitaireExample.tscn',
                                    'res://examples/multiplayer/p2p_macau.tscn'])
            run('snapshot-benchmark', ['--scene', 'res://tests/SnapshotBenchmark.tscn'])
        roundtrip()
        if not opts.roundtrip_only:
            macau(2)
            macau(6)
        if not opts.roundtrip_only:
            with (LOGS / 'installation.log').open('w') as log:
                result = subprocess.run([sys.executable, str(ROOT / 'tests/check_install.py')],
                                        env={**os.environ, 'GODOT': ENGINE}, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=180)
            check('installation', result.returncode)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        print(error, file=sys.stderr)
        print(f'Logs: {LOGS}', file=sys.stderr)
        sys.exit(1)
