#!/usr/bin/env bash
# Fetch the kernel source tree.

set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORKSPACE=${WORKSPACE:?WORKSPACE must be set}
KERNEL_DIR="${WORKSPACE}/android-kernel"

group "Cloning kernel source"
info "${KERNEL_SOURCE} @ ${KERNEL_SOURCE_BRANCH}"

ref_exists "$KERNEL_SOURCE" "$KERNEL_SOURCE_BRANCH" \
	|| die "branch/tag '${KERNEL_SOURCE_BRANCH}' does not exist in ${KERNEL_SOURCE}"

	retry 3 git clone --recursive --depth=1 \
		-b "$KERNEL_SOURCE_BRANCH" "$KERNEL_SOURCE" "$KERNEL_DIR" \
		|| die "Failed to clone ${KERNEL_SOURCE}"

	rm -rf "$KERNEL_DIR/KernelSU-Next"
	rm -rf "$KERNEL_DIR/drivers/kernelsu"
	sudo ln -sf "$WORKSPACE/clang/bin/ld.lld" /usr/bin/ld
	sed -i 's/-Werror//g' "$KERNEL_DIR/Makefile"
	sed -i 's/CONFIG_CC_STACKPROTECTOR_STRONG=y/CONFIG_CC_STACKPROTECTOR_NONE=y/g' "$KERNEL_DIR/arch/arm64/configs/b1c1_defconfig"
	sed -i '/CONFIG_CC_STACKPROTECTOR_STRONG/d' "$KERNEL_DIR/arch/arm64/configs/b1c1_defconfig"
	sed -i 's/CONFIG_SHADOW_CALL_STACK=y/CONFIG_SHADOW_CALL_STACK=n/g' "$KERNEL_DIR/arch/arm64/configs/b1c1_defconfig"
	sed -i '/CONFIG_SHADOW_CALL_STACK/d' "$KERNEL_DIR/arch/arm64/configs/b1c1_defconfig"
	find "$KERNEL_DIR" -type f -exec sed -i 's/-Werror=unknown-warning-option//g' {} +
	find "$KERNEL_DIR" -type f -exec sed -i 's/-Werror=implicit-function-declaration//g' {} +

export KCFLAGS="-Wno-error"
export KCPPFLAGS="-Wno-error"

# KernelSU forks compute their version from the commit count, and several
# read it straight out of the enclosing git repo. A depth-1 clone reports 1
# commit, which produces a nonsense version. Unshallow just enough to count.
if [ -f "${KERNEL_DIR}/.git/shallow" ]; then
	debug "kernel tree is shallow; that is fine for building"
fi

KVER=$(kernel_version "$KERNEL_DIR") \
	|| die "could not read VERSION/PATCHLEVEL from ${KERNEL_DIR}/Makefile -- is this a kernel tree?"
export_env KERNEL_VERSION "$KVER"
export_env KERNEL_DIR "$KERNEL_DIR"
ok "kernel source ready (Linux ${KVER})"
summary "| Kernel | \`${KERNEL_SOURCE##*/}\` @ \`${KERNEL_SOURCE_BRANCH}\` (Linux ${KVER}) |"

# LOCALVERSION is used purely to decorate artifact names.
if is_true "${ADD_LOCALVERSION_TO_FILENAME:-false}" && [ -f "${KERNEL_DIR}/localversion" ]; then
	export_env LOCALVERSION "$(cat "${KERNEL_DIR}/localversion")"
else
	export_env LOCALVERSION ""
fi
endgroup
