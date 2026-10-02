#!/usr/bin/env bash
# Compile-only consumer verification for the GPU overlay-port profiles
# (ucx[cuda], ucc[cuda,nccl,nvls]).
#
# The installed C consumers in .github/tests/ports/{ucx,ucc}.c are compiled and
# linked against the installed vcpkg prefix, but the resulting binaries are
# never executed. This profile has no GPU and no NVIDIA kernel driver, and no
# CUDA/NCCL runtime call or hardware initialization may happen.
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}"
: "${TRIPLET:?TRIPLET must be set}"
: "${PORT:?PORT must be set}"
CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda-12.8}"
FEATURES="${FEATURES:-}"

root="$GITHUB_WORKSPACE/installed/$TRIPLET"
source_file="$GITHUB_WORKSPACE/.github/tests/ports/$PORT.c"
test -s "$root/share/$PORT/copyright"
test -f "$source_file"

cuda_libdir="$CUDA_ROOT/targets/x86_64-linux/lib"
cuda_stubs="$cuda_libdir/stubs"
features=",${FEATURES},"

compiler=cc
includes=("-I$root/include")
modules=()
libraries=()
case "$PORT" in
  ucx) modules=(ucx); libraries=(-lucp -luct -lucs -lucm -pthread -ldl -lrt -lm) ;;
  ucc) modules=(ucc); libraries=(-lucc -pthread) ;;
  *) echo "No GPU consumer mapping for $PORT" >&2; exit 1 ;;
esac

# The feature providers must be provisioned userspace libraries. libcuda and
# libnvidia-ml are the driver/NVML development stubs plus the SONAME links
# created by the workflow.
provider_libs=()
if [[ "$features" == *",cuda,"* ]]; then
  provider_libs+=(
    "$cuda_libdir/libcudart.so.12"
    "$cuda_libdir/libcuda.so.1"
    "$cuda_libdir/libnvidia-ml.so.1"
    "$cuda_stubs/libcuda.so"
    "$cuda_stubs/libnvidia-ml.so"
  )
fi
if [[ "$features" == *",nccl,"* ]]; then
  provider_libs+=(
    /usr/lib/x86_64-linux-gnu/libnccl.so
    /usr/lib/x86_64-linux-gnu/libnccl.so.2
  )
fi
for provider in "${provider_libs[@]}"; do
  test -e "$provider" || { echo "::error::provider library missing: $provider"; exit 1; }
  echo "provider library present: $provider"
done

test ! -d "$root/debug/include"

# Classic vcpkg builds both configurations; both are verified here.
for config in release debug; do
  libdir="$root/lib"
  if [[ "$config" == debug ]]; then
    libdir="$root/debug/lib"
  fi
  test -d "$libdir"

  # Prove the requested providers are linked into the installed libraries and
  # modules of this configuration before any consumer is compiled. The CUDA and
  # NCCL transports are installed as UCX/UCC modules, so scan every shared
  # object under the configuration library directory.
  needed="$RUNNER_TEMP/$PORT-$config-needed.txt"
  : > "$needed"
  while IFS= read -r -d '' object; do
    readelf -d "$object" >> "$needed" 2>/dev/null || true
  done < <(find "$libdir" -type f \( -name '*.so' -o -name '*.so.*' \) -print0)
  grep -qE 'NEEDED.*libcudart\.so' "$needed" \
    || { echo "::error::$PORT/$config has no CUDA runtime dependency (libcudart)"; exit 1; }
  grep -qE 'NEEDED.*libcuda\.so' "$needed" \
    || { echo "::error::$PORT/$config has no CUDA driver dependency (libcuda)"; exit 1; }
  if [[ "$features" == *",nccl,"* ]]; then
    grep -qE 'NEEDED.*libnccl\.so' "$needed" \
      || { echo "::error::$PORT/$config has no NCCL dependency (libnccl)"; exit 1; }
  fi

  export LD_LIBRARY_PATH="$cuda_libdir:$cuda_stubs:$libdir:$root/lib"
  export PKG_CONFIG_LIBDIR="$libdir/pkgconfig"
  unset PKG_CONFIG_PATH

  primary_library="${libraries[0]#-l}"
  test -f "$libdir/lib$primary_library.so" \
    || { echo "::error::$libdir/lib$primary_library.so is missing"; exit 1; }

  for integration in direct pkgconfig; do
    binary="$RUNNER_TEMP/$PORT-$config-$integration"
    if [[ "$integration" == pkgconfig ]]; then
      "$compiler" -std=c11 "$source_file" \
        $(pkg-config --cflags --libs "${modules[@]}") \
        -Wl,-rpath,"$libdir" -Wl,-rpath-link,"$libdir" \
        -Wl,-rpath-link,"$cuda_libdir" -Wl,-rpath-link,"$cuda_stubs" \
        -o "$binary"
    else
      "$compiler" -std=c11 "$source_file" "${includes[@]}" -L"$libdir" \
        "${libraries[@]}" \
        -Wl,-rpath,"$libdir" -Wl,-rpath-link,"$libdir" \
        -Wl,-rpath-link,"$cuda_libdir" -Wl,-rpath-link,"$cuda_stubs" \
        -o "$binary"
    fi
    test -x "$binary"
    echo "compiled and linked (not executed): $PORT / $config / $integration"
  done
done

# NVLS is a compile-time UCC feature: UCC's configure must have accepted the
# sm_90/sm_100 gencodes and enabled the NVLS algorithms. No NVSwitch hardware
# is needed or touched at compile time.
if [[ "$features" == *",nvls,"* ]]; then
  if ! grep -Rqs 'NVLS support: enabled' "$GITHUB_WORKSPACE/vcpkg/buildtrees/ucc" \
     && ! find "$GITHUB_WORKSPACE/vcpkg/buildtrees/ucc" -name '*_nvls.o' -print -quit | grep -q .; then
    echo "::error::UCC NVLS configure/build evidence missing"
    exit 1
  fi
  echo "UCC NVLS configure/build evidence present"
fi

echo "GPU compile-only verification passed: $PORT[$FEATURES] / $TRIPLET"
