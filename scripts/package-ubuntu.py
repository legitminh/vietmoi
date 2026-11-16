#!/usr/bin/env python3
"""Package a staged /usr tree on its matching Ubuntu build host."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]


def output(*command):
    return subprocess.check_output(command, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", type=Path, default=ROOT / "build/linux-system-root")
    parser.add_argument("--output", type=Path, default=ROOT / "build/releases")
    parser.add_argument("--prepare-only", type=Path, help="Write a package tree for dpkg-deb on another host")
    args = parser.parse_args()
    stage = args.stage.resolve()
    if not (stage / "usr/lib/sieuviet/libSieuvietEngine.so").is_file():
        parser.error("First run build-linux.py --prefix /usr --destdir build/linux-system-root")
    release = json.loads((ROOT / "Design/brand.json").read_text())
    distro = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
    ubuntu = distro["VERSION_ID"].strip('"')
    if distro["ID"].strip('"') != "ubuntu":
        parser.error("Build this package on Ubuntu")
    arch = output("dpkg", "--print-architecture")
    dependencies = {"python3", "python3-gi", "gir1.2-gtk-3.0"}
    # Resolve the complete native dependency closure, excluding the bundled Swift runtime.
    for binary in stage.rglob("*"):
        if not binary.is_file():
            continue
        with binary.open("rb") as stream:
            if stream.read(4) != b"\x7fELF":
                continue
        linked = output("ldd", str(binary))
        if "not found" in linked:
            raise SystemExit(f"Missing packaged dependency for {binary}:\n{linked}")
        for line in linked.splitlines():
            parts = line.split()
            if len(parts) < 3 or parts[1] != "=>" or not parts[2].startswith("/"):
                continue
            library = Path(parts[2]).resolve()
            if library.is_relative_to(stage):
                continue
            owner = output("dpkg-query", "-S", str(library)).split(": ", 1)[0]
            package, version = output("dpkg-query", "-W", "-f=${Package} ${Version}", owner).split()
            dependencies.add(f"{package} (>= {version})")
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sieuviet-deb-") as temporary:
        tree = Path(temporary)
        shutil.copytree(stage / "usr", tree / "usr")
        control = tree / "DEBIAN"
        control.mkdir()
        installed = sum(p.stat().st_size for p in (tree / "usr").rglob("*") if p.is_file()) // 1024
        (control / "control").write_text(
            f"Package: sieuviet\nVersion: {release['version']}-{release['build']}\n"
            f"Architecture: {arch}\nMaintainer: siêu việt contributors <noreply@github.com>\n"
            f"Installed-Size: {installed}\nSection: utils\nPriority: optional\n"
            f"Depends: {', '.join(sorted(dependencies))}\nRecommends: ibus | fcitx5\n"
            "Homepage: https://github.com/legitminh/vietmoi\n"
            f"Description: Bộ gõ siêu việt cho Ubuntu {ubuntu}\n"
            " Shared Swift engine, IBus and Fcitx 5 adapters, and native settings.\n"
            " Select the keyboard in your input framework after installation.\n")
        document = tree / "usr/share/doc/sieuviet"
        document.mkdir(parents=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/copy-guides.py"), str(document), "README", "README.en.md"], check=True)
        notices = ROOT / "ThirdPartyNotices"
        if notices.exists():
            shutil.copytree(notices, document / "ThirdPartyNotices")
        if args.prepare_only:
            shutil.copytree(tree, args.prepare_only.resolve())
            print(args.prepare_only.resolve())
            return
        archive = destination / f"sieuviet-{release['version']}-ubuntu-{ubuntu}-{arch}.deb"
        subprocess.run(["dpkg-deb", "--root-owner-group", "--build", "-Zxz", str(tree), str(archive)], check=True)
        print(archive)


if __name__ == "__main__":
    main()
