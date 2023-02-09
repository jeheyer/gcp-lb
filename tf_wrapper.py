#!/usr/bin/env python3

import subprocess, platform, re

SYSTEM = platform.system().lower()

if "win" in SYSTEM:
    print("WINDOWS")
if re.match(r"linux|darwin|bsd", SYSTEM):
    print("UNIX")

process = ['/usr/local/bin/terraform', 'workspace', 'show']

env = {}

TF_WORKSPACE = env.get("TF_WORKSPACE", "default")

print(TF_WORKSPACE)
