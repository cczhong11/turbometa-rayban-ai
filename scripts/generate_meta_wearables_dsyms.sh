#!/bin/sh

set -eu

if [ "${ACTION:-}" != "install" ]; then
  echo "Skipping Meta Wearables dSYM generation because ACTION=${ACTION:-unset}"
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ] || [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
  echo "Skipping Meta Wearables dSYM generation because archive environment is incomplete"
  exit 0
fi

frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
dsym_dir="${DWARF_DSYM_FOLDER_PATH}"

if [ ! -d "${frameworks_dir}" ]; then
  echo "Skipping Meta Wearables dSYM generation because ${frameworks_dir} does not exist"
  exit 0
fi

generate_dsym() {
  framework_name="$1"
  framework_binary="${frameworks_dir}/${framework_name}.framework/${framework_name}"
  output_path="${dsym_dir}/${framework_name}.framework.dSYM"
  log_path="${TMPDIR:-/tmp}/${framework_name}.dsymutil.log"

  if [ ! -f "${framework_binary}" ]; then
    echo "Skipping ${framework_name}: framework binary not found at ${framework_binary}"
    return 0
  fi

  echo "Generating dSYM for ${framework_name}"
  rm -rf "${output_path}"
  if ! xcrun dsymutil "${framework_binary}" -o "${output_path}" > /dev/null 2>"${log_path}"; then
    echo "Failed to generate dSYM for ${framework_name}"
    cat "${log_path}"
    rm -f "${log_path}"
    return 1
  fi

  if [ -s "${log_path}" ]; then
    echo "dsymutil emitted warnings for ${framework_name}; generated dSYM anyway"
  fi

  rm -f "${log_path}"
  xcrun dwarfdump --uuid "${output_path}"
}

generate_dsym "MWDATCamera"
generate_dsym "MWDATCore"
generate_dsym "MWDATMockDevice"
