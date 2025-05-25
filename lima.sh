#!/usr/bin/env bash
set -eu

case "${BIOS}" in
  uefi) legacyBIOS=false;;
  legacy) legacyBIOS=true;;
esac

case "$(uname)" in
  Darwin) display=cocoa;;
  # Linux) display=gtk;;
  Linux) display=none;;
esac
cat <<EOF >"${Variant}.yaml"
arch: "${ARCH}"
images:
- location: "/tmp/lima/${OUT_IMG}"
  arch: "${ARCH}"
mounts:
- location: "/tmp/lima"
  writable: true
mountType: 9p
ssh:
  localPort: 0
firmware:
  legacyBIOS: $legacyBIOS
video:
  display: $display
containerd:
  system: false
  user: false
provision:
- mode: dependency
  skipDefaultDependencyResolution: true
  script: |
    #!/bin/sh
    set -eu
EOF

limactl delete -f "${Variant}"
limactl start --debug --tty=false "${Variant}.yaml"