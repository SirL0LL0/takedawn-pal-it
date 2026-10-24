#!/usr/bin/env python3
"""package.py: the Windows package and its zip, without a bash shell.

The same package tools/release/build-windows.sh makes (the program, SDL2,
the licences and the read-me), plus the icon as a file, the enhancements
file with the language in it, and the zip with the sums beside it.

Usage: python tools\\win\\package.py [--build DIR] [--deps DIR]
       [--toolkit DIR] [--out DIR] [--region PAL|NTSC-U] [--version X.Y.Z]

The build directory is the one tools\\win\\release.bat wrote (it holds
bin\\Takedawn.exe and takedawn.ico). The zip lands in <out> (dist by
default), named Takedawn-<version>-<region>-windows-x64.zip, with
SHA256SUMS and BUILDINFO beside it.
"""
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import zipfile

# The licences of everything in the package, and where they come from: the
# names are the ones the setup window's "About and licences" lists
# (tools/install/gui/installer_window.cpp).
LICENSES = [
    ("THIRD_PARTY.txt", "repo:tools/release/licenses/THIRD_PARTY_NOTICES.md"),
    ("takedawn-LICENSE.txt", "repo:LICENSE"),
    ("xboxrecomp-LICENSE.txt", "toolkit:LICENSE"),
    ("xboxrecomp-NOTICE.txt", "toolkit:NOTICE"),
    ("xboxrecomp-LGPL-2.1.txt", "toolkit:LICENSES/LGPL-2.1.txt"),
    ("DearImGui-MIT.txt", "toolkit:third_party/imgui/LICENSE.txt"),
    ("SMAA-MIT.txt", "toolkit:third_party/smaa/LICENSE.txt"),
    ("DejaVu-fonts-LICENSE.txt", "toolkit:third_party/dejavu/LICENSE.txt"),
]

# The texts in tools/release/licenses, all of them.
LICENSE_DIR = "tools/release/licenses"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def pe_imports(path):
    """The DLLs the executable imports (the PE import directory)."""
    import struct
    d = open(path, "rb").read()
    e = struct.unpack_from("<I", d, 0x3C)[0]
    nsec = struct.unpack_from("<H", d, e + 6)[0]
    opt = e + 24
    magic = struct.unpack_from("<H", d, opt)[0]
    ddir = opt + (112 if magic == 0x20B else 96)
    imp_rva = struct.unpack_from("<I", d, ddir + 8)[0]
    sec = opt + struct.unpack_from("<H", d, e + 20)[0]

    def rva2off(rva):
        for i in range(nsec):
            o = sec + 40 * i
            va = struct.unpack_from("<I", d, o + 12)[0]
            vs = struct.unpack_from("<I", d, o + 8)[0]
            raw = struct.unpack_from("<I", d, o + 20)[0]
            if va <= rva < va + max(vs, 1):
                return raw + (rva - va)
        return None

    names = []
    off = rva2off(imp_rva)
    while off is not None:
        ent = d[off:off + 20]
        if len(ent) < 20 or ent == b"\x00" * 20:
            break
        name_rva = struct.unpack_from("<I", ent, 12)[0]
        if name_rva == 0:
            break
        no = rva2off(name_rva)
        if no is None:
            break
        end = d.index(b"\x00", no)
        names.append(d[no:end].decode("ascii", "replace"))
        off += 20
    return names


# The DLLs Windows itself has: the program may import them, they do not
# travel with the package. Everything else must be in it, except the Vulkan
# loader, which is the graphics driver's own.
SYSTEM_DLLS = re.compile(
    r"^(KERNEL32|USER32|GDI32|ADVAPI32|SHELL32|ole32|OLEAUT32|COMCTL32|"
    r"COMDLG32|WS2_32|WINMM|WINHTTP|WINSPOOL|MSVCRT|dbghelp|IMM32|"
    r"SHLWAPI|vulkan-1|api-ms-win-.*)\.dll$", re.IGNORECASE)


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def git_commit(path):
    try:
        out = subprocess.run(["git", "-C", path, "rev-parse", "--short=12", "HEAD"],
                             capture_output=True, text=True, check=True)
        commit = out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"
    try:
        dirty = subprocess.run(["git", "-C", path, "status", "--porcelain"],
                               capture_output=True, text=True, check=True)
        if dirty.stdout.strip():
            commit += "-dirty"
    except (OSError, subprocess.CalledProcessError):
        pass
    return commit


def main():
    ap = argparse.ArgumentParser()
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    ap.add_argument("--root", default=root)
    ap.add_argument("--build", default=None)
    ap.add_argument("--deps", default=os.environ.get("BO3_WINDEPS",
                                                     os.path.join(os.environ.get("LOCALAPPDATA", ""),
                                                                  "bo3-windeps")))
    ap.add_argument("--toolkit", default=os.environ.get("XBOXRECOMP_DIR",
                                                        os.path.join(root, "..", "xboxrecomp")))
    ap.add_argument("--out", default=os.path.join(root, "dist"))
    ap.add_argument("--region", default=os.environ.get("BO3_REGION", "NTSC-U"))
    ap.add_argument("--version", default=None)
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    build = os.path.abspath(args.build or os.path.join(root, "build", "release"))
    deps = os.path.abspath(args.deps)
    toolkit = os.path.abspath(args.toolkit)
    out = os.path.abspath(args.out)
    pal = args.region.upper() == "PAL"

    version = args.version
    if not version:
        version = read_text(os.path.join(root, "VERSION")).split("\n")[0].strip()
    codename = ""
    lines = read_text(os.path.join(root, "VERSION")).split("\n")
    if len(lines) > 1:
        codename = lines[1].strip()

    exe = os.path.join(build, "bin", "Takedawn.exe")
    if not os.path.isfile(exe):
        raise SystemExit("missing %s -- run tools\\win\\release.bat first" % exe)
    ico = os.path.join(build, "takedawn.ico")
    sdl = os.path.join(deps, "SDL2", "x86_64-w64-mingw32", "bin", "SDL2.dll")
    if not os.path.isfile(sdl):
        raise SystemExit("missing %s" % sdl)

    tag = "pal" if pal else "ntsc-u"
    pkg_name = "Takedawn-%s-windows-x64" % version
    if pal:
        pkg_name = "Takedawn-%s-pal-windows-x64" % version
    pkg = os.path.join(build, pkg_name)
    if os.path.isdir(pkg):
        shutil.rmtree(pkg)
    os.makedirs(os.path.join(pkg, "licenses"))

    # The program, its library, the icon and the enhancements file.
    shutil.copy2(exe, os.path.join(pkg, "Takedawn.exe"))
    shutil.copy2(sdl, os.path.join(pkg, "SDL2.dll"))
    if os.path.isfile(ico):
        shutil.copy2(ico, os.path.join(pkg, "takedawn.ico"))
    enhance = os.path.join(root, "config", "enhance.toml.default")
    if os.path.isfile(enhance):
        shutil.copy2(enhance, os.path.join(pkg, "enhance.toml"))

    # The threading runtime, when the build links it as a DLL (the
    # toolchain's x86_64 bin).
    mingw = os.path.join(deps, "llvm-mingw", "x86_64-w64-mingw32", "bin")
    for candidate in (os.path.join(mingw, "libwinpthread-1.dll"),
                      os.path.join(deps, "llvm-mingw", "bin", "libwinpthread-1.dll")):
        if os.path.isfile(candidate):
            shutil.copy2(candidate, os.path.join(pkg, "libwinpthread-1.dll"))
            break

    # Every DLL the program imports that Windows does not have must be in
    # the package: a missing one is a program that does not start.
    missing = []
    for dll in pe_imports(exe):
        if SYSTEM_DLLS.match(dll):
            continue
        if not os.path.isfile(os.path.join(pkg, dll)):
            missing.append(dll)
    if missing:
        raise SystemExit("the program imports %s, which the package does not have"
                         % ", ".join(missing))

    # The licences.
    for name, rel in LICENSES:
        src = os.path.join(toolkit, rel.split(":", 1)[1]) if rel.startswith("toolkit:") \
            else os.path.join(root, rel.split(":", 1)[1])
        if not os.path.isfile(src):
            continue
        shutil.copy2(src, os.path.join(pkg, "licenses", name))
    lic_dir = os.path.join(root, LICENSE_DIR)
    for f in sorted(os.listdir(lic_dir)):
        if f.endswith(".txt") and f != "THIRD_PARTY_NOTICES.md":
            shutil.copy2(os.path.join(lic_dir, f), os.path.join(pkg, "licenses", f))

    # The read-me, in English; for the European disc its Italian translation
    # beside it (LEGGIMI.txt). UTF-8 with a mark, so Notepad shows the
    # accented letters.
    disc = "PAL (Europe)" if pal else "NTSC-U (North America)"
    readmes = [("README-pal.txt" if pal else "README.txt", "README.txt")]
    if pal:
        readmes.append(("README-pal-it.txt", "LEGGIMI.txt"))
    for src, dst in readmes:
        text = read_text(os.path.join(root, "tools", "release", "windows", src))
        text = text.replace("@VERSION@", version).replace("@DISC@", disc)
        with open(os.path.join(pkg, dst), "wb") as f:
            f.write(b"\xef\xbb\xbf" + text.replace("\n", "\r\n").encode("utf-8"))

    # The zip.
    os.makedirs(out, exist_ok=True)
    zip_path = os.path.join(out, pkg_name + ".zip")
    if os.path.isfile(zip_path):
        os.remove(zip_path)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _dirs, files in os.walk(pkg):
            for f in files:
                full = os.path.join(base, f)
                rel = os.path.relpath(full, os.path.dirname(pkg))
                z.write(full, rel.replace("\\", "/"))

    # The sums and what was built.
    with open(os.path.join(out, "SHA256SUMS"), "w", encoding="utf-8", newline="\n") as f:
        f.write("%s  %s\n" % (sha256_file(zip_path), os.path.basename(zip_path)))

    stamp = os.path.join(root, "src", "game", "recomp", "gen", "regen.stamp")
    stamp_lines = read_text(stamp).split("\n") if os.path.isfile(stamp) else []
    info = [
        "Takedawn %s%s" % (version, (" \"%s\"" % codename) if codename else ""),
        "region %s" % args.region,
        "package %s" % os.path.basename(zip_path),
        "game commit %s" % git_commit(root),
        "toolkit commit %s" % git_commit(toolkit),
        "program %s" % sha256_file(exe),
    ]
    info += [l for l in stamp_lines if l.strip()]
    info += [
        "",
        "The game data is not in the package: the player brings the disc.",
        "The program is not code-signed.",
    ]
    with open(os.path.join(out, "BUILDINFO"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(info) + "\n")

    print("package : %s" % pkg)
    print("zip     : %s (%.1f MB)" % (zip_path, os.path.getsize(zip_path) / 1048576.0))
    print("sums    : %s" % os.path.join(out, "SHA256SUMS"))
    print("info    : %s" % os.path.join(out, "BUILDINFO"))


if __name__ == "__main__":
    main()
