#!/usr/bin/env python3
"""Store screenshots: runs integration_test/screenshots_test.dart on a booted
iOS simulator and captures the simulator screen each time the test prints
SHOT:<name>.

  tool/screenshots.py <simulator-udid> <out-dir> [extra flutter args...]

The iPhone 17 Pro Max simulator gives 1320x2868, the App Store's 6.9" size.
"""
import os, re, subprocess, sys

udid, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
subprocess.run(['xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41',
                '--batteryState', 'charged', '--batteryLevel', '100',
                '--cellularBars', '4', '--wifiBars', '3'], check=False)
cmd = ['flutter', 'drive', '--driver=test_driver/integration_test.dart',
       '--target=integration_test/screenshots_test.dart', '-d', udid] + sys.argv[3:]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
for line in p.stdout:
    sys.stdout.write(line)
    m = re.search(r'SHOT:(\w+)', line)
    if m:
        path = os.path.join(out, m.group(1) + '.png')
        subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', path],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f'>>> captured {path}', flush=True)
sys.exit(p.wait())
