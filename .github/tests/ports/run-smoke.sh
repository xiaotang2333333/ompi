#!/usr/bin/env bash
set -euo pipefail

root="$GITHUB_WORKSPACE/installed/$TRIPLET"
source_file="$GITHUB_WORKSPACE/.github/tests/ports/$PORT.c"
test -s "$root/share/$PORT/copyright"

compiler=cc
cross=false
if [[ "$TRIPLET" == arm64-* ]]; then
  compiler=aarch64-linux-gnu-gcc
  cross=true
fi
verify_arm64() {
  local file="$1"
  local headers="$RUNNER_TEMP/$PORT-elf-headers.txt"
  if [[ "$file" == *.a ]]; then
    # Static libraries are ar archives, not ELF files; verify their members.
    local first
    first=$(ar t "$file" | head -n1)
    test -n "$first"
    ar p "$file" "$first" > "$RUNNER_TEMP/$PORT-archmember.o"
    readelf -h "$RUNNER_TEMP/$PORT-archmember.o" > "$headers"
  else
    readelf -h "$file" > "$headers"
  fi
  awk '$1 == "Machine:" { count++; if ($2 != "AArch64") bad = 1 }
       END { exit (!count || bad) }' "$headers"
}

includes=("-I$root/include")
modules=()
libraries=()
case "$PORT" in
  knem|valgrind) ;;
  hwloc)
    modules=(hwloc)
    libraries=(-lhwloc -lpthread -ldl -lm)
    ;;
  qthreads)
    modules=(qthread)
    libraries=(-lqthread -pthread -ldl -lrt -lm)
    if [[ ",${FEATURES:-}," == *",hwloc,"* ]]; then
      modules+=(hwloc)
      libraries+=(-lhwloc)
    fi
    ;;
  memkind)
    modules=(memkind)
    libraries=(-lmemkind -lnuma -pthread -ldl -lm)
    if [[ ",${FEATURES:-}," == *",hwloc,"* ]]; then
      modules+=(hwloc)
      libraries+=(-lhwloc)
    fi
    if [[ ",${FEATURES:-}," == *",daxctl,"* ]]; then
      modules+=(libdaxctl)
      libraries+=(-ldaxctl -luuid -lkmod)
    fi
    ;;
  munge) modules=(munge); libraries=(-lmunge) ;;
  libnl)
    includes+=("-I$root/include/libnl3")
    modules=(libnl-route-3.0 libnl-3.0)
    libraries=(-lnl-route-3 -lnl-3 -pthread -lm)
    ;;
  ucx) modules=(ucx); libraries=(-lucp -luct -lucs -lucm -pthread -ldl -lrt -lm) ;;
  ucc) modules=(ucc); libraries=(-lucc -pthread) ;;
  portals4) libraries=(-lportals -lev -pthread -ldl -lrt -lm) ;;
  pvfs2) libraries=(-lpvfs2 -pthread -ldl -lrt -lm) ;;
  psm2) modules=(libpsm2); libraries=(-lpsm2 -lnuma -pthread -ldl -lrt) ;;
  rdma-core) modules=(librdmacm libibverbs); libraries=(-lrdmacm -libverbs -lnl-route-3 -lnl-3 -pthread -ldl) ;;
  kmod)
    modules=(libkmod)
    libraries=(-lkmod -pthread -ldl)
    for feature in openssl xz zlib zstd; do
      if [[ ",${FEATURES:-}," == *",$feature,"* ]]; then
        case "$feature" in
          openssl) libraries+=(-lcrypto) ;;
          xz) libraries+=(-llzma) ;;
          zlib) libraries+=(-lz) ;;
          zstd) libraries+=(-lzstd) ;;
        esac
      fi
    done
    ;;
  ndctl) modules=(libndctl libdaxctl); libraries=(-lndctl -ldaxctl -ludev -lkmod -luuid -llzma -llz4 -lzstd -pthread -ldl -lm -lrt) ;;
  libsystemd)
    source_file="$GITHUB_WORKSPACE/.github/tests/ports/libudev.c"
    modules=(libudev)
    libraries=(-ludev -llzma -llz4 -lzstd -pthread -ldl -lm -lrt)
    ;;
  xpmem) modules=(cray-xpmem); libraries=(-lxpmem -pthread) ;;
  openmpi) modules=(ompi-c); libraries=(-lmpi) ;;
  *) echo "No consumer mapping for $PORT" >&2; exit 1 ;;
esac
test -f "$source_file"

configs=(release debug)
if [[ "$LINKAGE" == headers ]]; then
  configs=(release)
fi
for config in "${configs[@]}"; do
  libdir="$root/lib"
  if [[ "$config" == debug ]]; then
    libdir="$root/debug/lib"
  fi
  export LD_LIBRARY_PATH="$libdir:$root/lib"
  export PKG_CONFIG_LIBDIR="$libdir/pkgconfig"
  unset PKG_CONFIG_PATH
  if [[ "$PORT" == openmpi ]]; then
    export PATH="$root/tools/openmpi/debug/bin:$root/tools/openmpi/bin:$PATH"
  fi
  if (( ${#libraries[@]} )); then
    primary_library="${libraries[0]#-l}"
    extension=so
    if [[ "$LINKAGE" == static ]]; then
      extension=a
    fi
    test -f "$libdir/lib$primary_library.$extension"
    if [[ "$cross" == true ]]; then
      verify_arm64 "$libdir/lib$primary_library.$extension"
    fi
  fi
  for module in "${modules[@]}"; do
    pkg-config --modversion "$module"
  done
  pkgconfig_options=()
  if [[ "$LINKAGE" == static ]]; then
    pkgconfig_options+=(--static)
  fi

  # Test declared pkg-config interfaces when available, and direct linkage
  # for every package. Both use installed files only, never build-tree paths.
  integrations=(direct)
  if (( ${#modules[@]} )); then
    integrations+=(pkgconfig)
  fi
  for integration in "${integrations[@]}"; do
    binary="$RUNNER_TEMP/$PORT-$config-$integration"
    if [[ "$integration" == pkgconfig ]]; then
      "$compiler" -std=c11 "$source_file" \
        $(pkg-config --cflags --libs "${pkgconfig_options[@]}" "${modules[@]}") \
        -Wl,-rpath,"$libdir" -Wl,-rpath-link,"$libdir" -o "$binary"
    else
      direct_libs=("${libraries[@]}")
      if [[ "$config" == debug ]]; then
        # lz4 names its debug shared library liblz4d.so.
        for i in "${!direct_libs[@]}"; do
          if [[ "${direct_libs[$i]}" == "-llz4" ]]; then
            direct_libs[$i]="-llz4d"
          fi
        done
      fi
      "$compiler" -std=c11 "$source_file" "${includes[@]}" -L"$libdir" \
        "${direct_libs[@]}" -Wl,-rpath,"$libdir" -Wl,-rpath-link,"$libdir" -o "$binary"
    fi
    echo "Testing $PORT / $config / $integration"
    if [[ "$cross" == true ]]; then
      verify_arm64 "$binary"
      echo "ARM64 consumer compiled and linked; execution requires an ARM64 runner"
    elif [[ "${COMPILE_ONLY:-false}" == true ]]; then
      echo "Hardware-dependent profile compiled and linked; runtime requires its kernel driver"
    else
      timeout 60s "$binary"
    fi
  done
done
test ! -d "$root/debug/include"
