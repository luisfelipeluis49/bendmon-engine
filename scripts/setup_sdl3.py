#!/usr/bin/env python3
"""Build the pinned SDL3 release into this checkout without system installs."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "build/deps/SDL3-3.4.16.tar.gz"
SOURCE = ROOT / "build/deps/SDL3-3.4.16"
BUILD = ROOT / "build/deps/sdl3-build"
PREFIX = ROOT / "build/deps/sdl3-prefix"
SHA256 = "7322236cd12090c3eb40b9728be4d49c76f66ad17d04369584d4ecad5cf77c68"
URL = "https://github.com/libsdl-org/SDL/releases/download/release-3.4.16/SDL3-3.4.16.tar.gz"
WAYLAND_RUNTIME_SHA256 = {
    # Local runtime copies from the Freedesktop SDK 25.08 used on this host.
    "libwayland-client.so.0": "2e7bfc0e23191632d9505f622c309f2d940d29aec161d5563d0a44f5b041c579",
    "libwayland-cursor.so.0": "b79f9cee548480d91c5394b8596d0fa58417e06c59a4fe643ccb899a9333233d",
    "libwayland-egl.so.1": "8d9564959ead3ec7696438d0e8a1f1328460f72318f17b64f6d83e59010b0a1a",
    "libEGL.so.1": "7da9a03c181abf73a37fd652e13df441c616f13030fee5ec87a0f4886432dec5",
    "libxkbcommon.so.0": "0d39775c5d7c075843e1ccb4e65d3c09a7cd3b033fcf3c20346d3f5d13bdcdf7",
}
WAYLAND_LINKER_SHA256 = {
    "libEGL.so": "7da9a03c181abf73a37fd652e13df441c616f13030fee5ec87a0f4886432dec5",
    "libxkbcommon.so": "0d39775c5d7c075843e1ccb4e65d3c09a7cd3b033fcf3c20346d3f5d13bdcdf7",
}


def find_cmake() -> str:
    configured = os.environ.get("CMAKE")
    candidates = [configured] if configured else []
    candidates.append(shutil.which("cmake"))
    candidates.extend(
        str(path)
        for path in Path.home().glob(
            ".local/share/flatpak/runtime/org.freedesktop.Sdk/*/*/*/files/bin/cmake"
        )
    )
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise SystemExit("CMake is required; set CMAKE to a CMake 3.16+ executable")


def find_compiler(cmake: str) -> str:
    configured = os.environ.get("CC")
    if configured:
        return configured
    compiler = shutil.which("cc")
    if compiler:
        return compiler
    adjacent = Path(cmake).resolve().parent / "cc"
    if adjacent.exists():
        return str(adjacent)
    raise SystemExit("a C compiler is required; set CC to a C compiler executable")


def extract_source() -> None:
    if not ARCHIVE.is_file():
        ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            dir=ARCHIVE.parent, prefix="SDL3-3.4.16.", delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
        try:
            request = urllib.request.Request(URL, headers={"User-Agent": "bend-sdl3-setup"})
            with urllib.request.urlopen(request) as response, temporary_path.open("wb") as out:
                shutil.copyfileobj(response, out)
            downloaded = hashlib.sha256(temporary_path.read_bytes()).hexdigest()
            if downloaded != SHA256:
                raise SystemExit(f"SDL archive checksum mismatch: expected {SHA256}, got {downloaded}")
            os.replace(temporary_path, ARCHIVE)
        finally:
            temporary_path.unlink(missing_ok=True)
    actual = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
    if actual != SHA256:
        raise SystemExit(f"SDL archive checksum mismatch: expected {SHA256}, got {actual}")
    if (SOURCE / "CMakeLists.txt").is_file():
        return
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(ARCHIVE, "r:gz") as archive:
        for member in archive.getmembers():
            name = PurePosixPath(member.name)
            if name.is_absolute() or ".." in name.parts:
                raise SystemExit(f"unsafe path in SDL archive: {member.name}")
            if not name.parts or name.parts[0] != "SDL3-3.4.16":
                raise SystemExit(f"unexpected SDL archive root: {member.name}")
            if not (member.isdir() or member.isfile()):
                raise SystemExit(f"unsafe entry type in SDL archive: {member.name}")
        archive.extractall(ARCHIVE.parent, filter="data")


def copy_pinned_wayland_runtime(sdk_prefix: Path) -> bool:
    """Copy the exact SDK Wayland runtime needed by the local SDL build."""
    library_dir = sdk_prefix / "lib/x86_64-linux-gnu"
    sources = {name: library_dir / name for name in WAYLAND_RUNTIME_SHA256}
    if not all(path.is_file() for path in sources.values()):
        return False
    for name, path in sources.items():
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = WAYLAND_RUNTIME_SHA256[name]
        if actual != expected:
            raise SystemExit(
                f"Wayland runtime checksum mismatch for {name}: "
                f"expected {expected}, got {actual}"
            )
    destination = PREFIX / "lib/wayland"
    destination.mkdir(parents=True, exist_ok=True)
    for name, path in sources.items():
        shutil.copy2(path, destination / name)
    return True


def copy_pinned_wayland_linker_libraries(sdk_prefix: Path) -> Path | None:
    """Stage matching SDK development sonames for CMake's Wayland link step."""
    library_dir = sdk_prefix / "lib/x86_64-linux-gnu"
    sources = {name: library_dir / name for name in WAYLAND_LINKER_SHA256}
    if not all(path.is_file() for path in sources.values()):
        return None
    for name, path in sources.items():
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = WAYLAND_LINKER_SHA256[name]
        if actual != expected:
            raise SystemExit(
                f"Wayland linker library checksum mismatch for {name}: "
                f"expected {expected}, got {actual}"
            )
    destination = ROOT / "build/deps/sdl3-host-wayland-lib"
    destination.mkdir(parents=True, exist_ok=True)
    for name, path in sources.items():
        shutil.copy2(path, destination / name)
    return destination


def main() -> None:
    cmake = find_cmake()
    compiler = find_compiler(cmake)
    extract_source()
    cache = BUILD / "CMakeCache.txt"
    if cache.is_file() and f"CMAKE_C_COMPILER:FILEPATH={compiler}" not in cache.read_text():
        shutil.rmtree(BUILD)
    configure = [
            cmake,
            "-S", str(SOURCE),
            "-B", str(BUILD),
            "-G", "Ninja",
            f"-DCMAKE_C_COMPILER={compiler}",
            f"-DCMAKE_INSTALL_PREFIX={PREFIX}",
            "-DCMAKE_SUPPRESS_REGENERATION=ON",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DSDL_SHARED=ON",
            "-DSDL_STATIC=OFF",
            "-DSDL_TEST_LIBRARY=OFF",
            "-DSDL_TESTS=OFF",
            "-DSDL_EXAMPLES=OFF",
            "-DSDL_HIDAPI=OFF",
            "-DSDL_OPENGL=OFF",
            "-DSDL_LIBUDEV=OFF",
            "-DSDL_X11=ON",
            "-DSDL_X11_XCURSOR=OFF",
            "-DSDL_X11_XDBE=OFF",
            "-DSDL_X11_XINPUT=OFF",
            "-DSDL_X11_XFIXES=OFF",
            "-DSDL_X11_XRANDR=OFF",
            "-DSDL_X11_XSCRNSAVER=OFF",
            "-DSDL_X11_XSHAPE=OFF",
            "-DSDL_X11_XSYNC=OFF",
            "-DSDL_X11_XTEST=OFF",
            "-DSDL_FRIBIDI=OFF",
            "-DSDL_LIBTHAI=OFF",
            "-DSDL_WAYLAND=ON",
            "-DSDL_WAYLAND_SHARED=ON",
            "-DSDL_WAYLAND_LIBDECOR=OFF",
            "-DSDL_DBUS=OFF",
            "-DSDL_IBUS=OFF",
            "-DSDL_JACK=OFF",
            "-DSDL_KMSDRM=OFF",
            "-DSDL_ALSA=ON",
            "-DSDL_ALSA_SHARED=ON",
            "-DSDL_PULSEAUDIO=OFF",
            "-DSDL_PIPEWIRE=OFF",
        ]
    cmake_path = Path(cmake)
    sdk_prefix = None
    build_environment = os.environ.copy()
    if "flatpak/runtime" in str(cmake_path):
        sdk_prefix = cmake_path.parent.parent
        sdk_pkgconfig = ":".join(
            [
                str(sdk_prefix / "lib/x86_64-linux-gnu/pkgconfig"),
                str(sdk_prefix / "share/pkgconfig"),
            ]
        )
        inherited_pkgconfig = build_environment.get("PKG_CONFIG_PATH", "")
        build_environment["PKG_CONFIG_PATH"] = ":".join(
            part for part in (sdk_pkgconfig, inherited_pkgconfig) if part
        )
        configure.append(f"-DCMAKE_IGNORE_PREFIX_PATH={sdk_prefix}")
        configure.extend(
            [
                "-DX11_INCLUDE_DIR=/usr/include",
                "-DX11_INCLUDE_PATH=/usr/include",
            ]
        )
        ignored_sdk_paths = ";".join(
            [
                str(sdk_prefix / "include"),
                str(sdk_prefix / "lib/x86_64-linux-gnu"),
                str(sdk_prefix / "lib"),
            ]
        )
        configure.append(f"-DCMAKE_IGNORE_PATH={ignored_sdk_paths}")
        sdk_alsa = sdk_prefix / "include/alsa"
        if not (Path("/usr/include/alsa/asoundlib.h").is_file()) and sdk_alsa.is_dir():
            local_alsa = ROOT / "build/deps/sdl3-host-alsa-include/alsa"
            if local_alsa.exists():
                shutil.rmtree(local_alsa)
            shutil.copytree(sdk_alsa, local_alsa)
            configure.extend(
                [
                    f"-DALSA_INCLUDE_DIR={local_alsa.parent}",
                    "-DALSA_LIBRARY=/usr/lib/x86_64-linux-gnu/libasound.so.2",
                ]
            )
        if not Path("/usr/include/xkbcommon/xkbcommon.h").is_file():
            sdk_xkbcommon = sdk_prefix / "include/xkbcommon"
            if sdk_xkbcommon.is_dir():
                local_xkbcommon = ROOT / "build/deps/sdl3-host-wayland-include/xkbcommon"
                if local_xkbcommon.exists():
                    shutil.rmtree(local_xkbcommon)
                shutil.copytree(sdk_xkbcommon, local_xkbcommon)
                inherited_cflags = build_environment.get("CFLAGS", "")
                configure.append(
                    f"-DCMAKE_C_FLAGS={inherited_cflags} -I{local_xkbcommon.parent}".strip()
                )
        local_wayland_libs = copy_pinned_wayland_linker_libraries(sdk_prefix)
        if local_wayland_libs:
            inherited_ldflags = build_environment.get("LDFLAGS", "")
            configure.append(
                f"-DCMAKE_SHARED_LINKER_FLAGS={inherited_ldflags} -L{local_wayland_libs}".strip()
            )
        sdk_x11 = sdk_prefix / "include/X11"
        if sdk_x11.is_dir():
            local_x11 = ROOT / "build/deps/sdl3-host-x11-include/X11"
            if local_x11.exists():
                shutil.rmtree(local_x11)
            shutil.copytree(sdk_x11, local_x11)
            configure.append(f"-DX11_INCLUDEDIR={local_x11.parent}")
    subprocess.run(configure, check=True, env=build_environment)
    if "flatpak/runtime" in str(cmake_path):
        ninja_file = BUILD / "build.ninja"
        sdk_include = str(sdk_prefix / "include")
        replacement = ""
        local_xkbcommon = ROOT / "build/deps/sdl3-host-wayland-include"
        if local_xkbcommon.is_dir():
            replacement = f" -isystem {local_xkbcommon}"
        ninja_file.write_text(
            ninja_file.read_text().replace(f" -isystem {sdk_include}", replacement)
        )
    subprocess.run([cmake, "--build", str(BUILD), "--parallel"], check=True, env=build_environment)
    subprocess.run([cmake, "--install", str(BUILD)], check=True, env=build_environment)
    if sdk_prefix and (BUILD / "include-config-release/build_config/SDL_build_config.h").is_file():
        config = (BUILD / "include-config-release/build_config/SDL_build_config.h").read_text()
        if "#define SDL_VIDEO_DRIVER_WAYLAND 1" in config:
            if not copy_pinned_wayland_runtime(sdk_prefix):
                raise SystemExit("SDL Wayland is enabled, but pinned local runtime libraries are missing")
    print(f"SDL 3.4.16 installed at {PREFIX}")


if __name__ == "__main__":
    main()
