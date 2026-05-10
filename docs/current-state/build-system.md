# Build System

> **Scope:** Build system as observed from `mod-ollama-chat.cmake`. All claims are **[source-backed]** unless marked.

---

## Overview

The module is built as part of AzerothCore's CMake module system. The file `mod-ollama-chat.cmake` is the sole build entry point. It does not define a standalone CMake project — it extends the existing `modules` CMake target. **[source-backed: mod-ollama-chat.cmake]**

Build entry condition:
```cmake
if(TARGET modules)
    # all dependency and link logic here
endif()
```

If the `modules` target does not exist, the entire cmake file is a no-op. **[source-backed]**

---

## Dependencies

### 1. nlohmann/json (required)

Resolution order **[source-backed: mod-ollama-chat.cmake]**:

1. **Bundled** — `deps/nlohmann/json.hpp` in the module directory (preferred)
2. **AzerothCore deps** — `${CMAKE_SOURCE_DIR}/deps/nlohmann`
3. **System** — `find_package(nlohmann_json CONFIG QUIET)` → `nlohmann_json::nlohmann_json`
4. **FATAL_ERROR** if none found

The bundled copy at `deps/nlohmann/json.hpp` means no system installation is needed in the standard case. **[source-backed]**

### 2. fmtlib (required)

Resolution order **[source-backed: mod-ollama-chat.cmake]**:

1. **AzerothCore target** — `if(TARGET fmt)` → links `fmt`
2. **System** — `find_package(fmt CONFIG QUIET)` → `fmt::fmt`
3. **FATAL_ERROR** with platform-specific install instructions if none found

Error message includes install instructions for Windows (vcpkg), Ubuntu/Debian, CentOS/RHEL, macOS, and Arch Linux. **[source-backed]**

### 3. cpp-httplib (required, bundled)

Header-only library included at `src/httplib.h`. No CMake `find_package` needed — the `src/` directory is added to include paths:
```cmake
target_include_directories(modules PRIVATE ${CMAKE_CURRENT_LIST_DIR}/src)
```
**[source-backed: mod-ollama-chat.cmake]**

### 4. OpenSSL (optional)

```cmake
find_package(OpenSSL QUIET)
if(OpenSSL_FOUND OR OPENSSL_FOUND)
    target_compile_definitions(modules PRIVATE CPPHTTPLIB_OPENSSL_SUPPORT)
    target_link_libraries(modules PRIVATE OpenSSL::SSL OpenSSL::Crypto)
```

- If found: HTTPS support is enabled via `CPPHTTPLIB_OPENSSL_SUPPORT` preprocessor define
- If not found: warning printed; only HTTP connections to the LLM endpoint are possible
- **[source-backed: mod-ollama-chat.cmake]**

### 5. Platform-Specific Libraries

**Windows** **[source-backed]**:
```cmake
target_link_libraries(modules PRIVATE ws2_32 crypt32)
```
- `ws2_32` — Winsock networking
- `crypt32` — Windows crypto (needed by OpenSSL on Windows)

**Linux / macOS** **[source-backed]**:
```cmake
target_link_libraries(modules PRIVATE pthread)
```

---

## Source File Discovery

The cmake file does **not** explicitly list `.cpp` source files. AzerothCore's module system uses glob patterns to discover source files automatically. **[inferred — the cmake file contains no `target_sources()` call; AC module cmake conventions use glob]**

All `.cpp` files in `src/` are expected to be compiled automatically when the module directory is registered with AzerothCore. If new source files are added during refactoring (Phase 3), they will be picked up without explicit cmake changes — but this should be verified against the specific AC version in use.

---

## CMake Minimum Requirements

Not declared in the module cmake file. Governed by the host AzerothCore CMakeLists.txt. **[inferred]**

---

## Build Prerequisites Summary

| Dependency | Required | Source |
|-----------|---------|--------|
| AzerothCore with `modules` target | Yes | Host project |
| mod-playerbots (`PlayerbotAI.h`, etc.) | Yes | Must be in AC include path **[inferred]** |
| nlohmann/json | Yes | Bundled — no action needed |
| fmtlib | Yes | Usually provided by AC; install separately if needed |
| cpp-httplib | Yes | Bundled — no action needed |
| OpenSSL | No | Only needed for HTTPS endpoint connections |
| pthread (Linux/macOS) | Yes | System library, normally present |
| ws2_32 + crypt32 (Windows) | Yes | Windows SDK, normally present |

---

## CI Status

Only a codestyle check is present at `apps/ci/ci-codestyle.sh`. No automated build verification CI exists in this repository. **[source-backed: apps/ci/ directory]**

See [plans/refactor-roadmap.md](../plans/refactor-roadmap.md) Phase 6 for the plan to add build CI.

---

## Build Steps (Summary)

Full operator instructions are in [usage/installation.md](../usage/installation.md). The short form:

```bash
# 1. Place module in AzerothCore modules/ directory
cd /path/to/azerothcore/modules
git clone https://github.com/DustinHendrickson/mod-ollama-chat.git

# 2. Install fmtlib if not already present (Ubuntu/Debian example)
sudo apt install libfmt-dev

# 3. Rebuild AzerothCore
cd /path/to/azerothcore
mkdir -p build && cd build
cmake .. -DMODULES_ENABLED=1   # flags may differ by AC version
make -j$(nproc)
```
