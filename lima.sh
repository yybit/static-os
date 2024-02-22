#!/usr/bin/env bash
set -eu

case "$(uname)" in
  Darwin) display=cocoa;;
  Linux) display=gtk;;
esac
cat <<EOF >"${Variant}.yaml"
arch: "${ARCH}"
images:
- location: "/tmp/lima/example-${ARCH}.img"
  arch: "${ARCH}"
mounts:
- location: "~/projects"
  writable: false
- location: "/tmp/lima"
  writable: true
mountType: 9p
ssh:
  localPort: 40022
firmware:
  legacyBIOS: true
video:
  display: $display
containerd:
  system: false
  user: false
provision:
- mode: dependency
  skipDefaultDependencyResolution: true
EOF

limactl delete -f "${Variant}"
limactl start --tty=false "${Variant}.yaml"