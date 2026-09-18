#!/usr/bin/env bash

# Trace xal walking a small dataset, with its debug logging and asserts enabled
#
# The release build xal is installed as walks until the OOM killer stops it,
# saying nothing on the way. A debug build logs every step and keeps the asserts
# on the headers it decodes, so the walk can be followed to wherever it derails.
set -u

XAL_SRC="$1"
DEV="$2"
SRC="$3"
MNT=/mnt/xal-probe
BUILD=/tmp/xal-debug
TRACE=/tmp/xal-trace.txt

rm -rf "${BUILD}"
meson setup "${BUILD}" "${XAL_SRC}" --buildtype=debug >/dev/null || exit 1
meson compile -C "${BUILD}" >/dev/null || exit 1

umount "${MNT}" 2>/dev/null
mkfs.xfs -f -q "${DEV}"
mkdir -p "${MNT}"
mount "${DEV}" "${MNT}"
python3 "${SRC}/cijoe/auxiliary/fil_dataset.py" populate \
	--mnt "${MNT}" --data-dir probe --classes 1 --files 2
umount "${MNT}"

# Capped, as the trace grows without bound while the walk runs away
timeout 300 "${BUILD}/xal" "${DEV}" --backend xfs --stats 2>&1 |
	head -c 20000000 >"${TRACE}"
echo "xal exit: ${PIPESTATUS[0]}, trace lines: $(wc -l <"${TRACE}")"

echo "--- first 150 lines"
head -150 "${TRACE}"
echo "--- last 80 lines"
tail -80 "${TRACE}"
