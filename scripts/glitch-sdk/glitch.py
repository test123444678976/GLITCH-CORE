#!/usr/bin/env python3
"""Initial GLITCH//CORE app SDK: validate, package and inspect .gcpkg apps."""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

SCHEMA_VERSION = 1
PACKAGE_SUFFIX = ".gcpkg"
ID_RE = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)*$")
VERSION_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
MANIFEST = "glitch-app.json"


class AppError(Exception):
    pass


def safe_relative(value: object, field: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value:
        raise AppError(f"{field} must be a non-empty POSIX relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise AppError(f"{field} contains an unsafe path: {value!r}")
    if path.as_posix() != value:
        raise AppError(f"{field} must use a normalized relative path")
    return value


def load_app(root: Path) -> tuple[dict, list[tuple[str, Path]]]:
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise AppError("application path must be a directory")
    manifest_path = root / MANIFEST
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise AppError(f"missing regular {MANIFEST}")
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AppError(f"cannot read manifest: {exc}") from exc
    if not isinstance(data, dict):
        raise AppError("manifest root must be a JSON object")
    required = ("schema", "id", "name", "version", "entrypoint", "runtime", "files")
    missing = [key for key in required if key not in data]
    if missing:
        raise AppError("missing manifest fields: " + ", ".join(missing))
    if data["schema"] != SCHEMA_VERSION:
        raise AppError(f"unsupported manifest schema: {data['schema']!r}")
    if not isinstance(data["id"], str) or not ID_RE.fullmatch(data["id"]):
        raise AppError("id must contain lowercase letters, digits, dots or hyphens")
    if not isinstance(data["name"], str) or not data["name"].strip():
        raise AppError("name must be a non-empty string")
    if not isinstance(data["version"], str) or not VERSION_RE.fullmatch(data["version"]):
        raise AppError("version must follow MAJOR.MINOR.PATCH")
    if data["runtime"] not in ("python3", "static"):
        raise AppError("runtime must be python3 or static")
    entrypoint = safe_relative(data["entrypoint"], "entrypoint")
    files = data["files"]
    if not isinstance(files, list) or not files:
        raise AppError("files must be a non-empty array")
    normalized = [safe_relative(item, "files[]") for item in files]
    if len(set(normalized)) != len(normalized):
        raise AppError("files contains duplicate paths")
    if MANIFEST in normalized:
        raise AppError(f"do not list {MANIFEST}; it is included automatically")
    if entrypoint not in normalized:
        raise AppError("entrypoint must also appear in files")
    resolved_files: list[tuple[str, Path]] = []
    for relative in normalized:
        candidate = root.joinpath(*PurePosixPath(relative).parts)
        current = root
        for part in PurePosixPath(relative).parts:
            current = current / part
            if current.is_symlink():
                raise AppError(f"symlinks are not allowed: {relative}")
        try:
            resolved = candidate.resolve(strict=True)
            resolved.relative_to(root)
        except (OSError, ValueError) as exc:
            raise AppError(f"missing or escaping app file: {relative}") from exc
        if not resolved.is_file():
            raise AppError(f"not a regular file: {relative}")
        resolved_files.append((relative, resolved))
    return data, resolved_files


def validate_command(args: argparse.Namespace) -> int:
    data, files = load_app(Path(args.app))
    print(f"Valid GLITCH app: {data['name']} ({data['id']})")
    print(f"Version: {data['version']} | Runtime: {data['runtime']}")
    print(f"Files: {len(files)}")
    return 0


def pack_command(args: argparse.Namespace) -> int:
    root = Path(args.app).resolve(strict=True)
    data, files = load_app(root)
    output = Path(args.output).resolve()
    if output == root or root in output.parents:
        raise AppError("package output must be outside the application source directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_name(output.name + ".tmp")
    try:
        with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(root / MANIFEST, MANIFEST)
            for relative, source in files:
                archive.write(source, relative)
        with zipfile.ZipFile(temp, "r") as archive:
            bad = archive.testzip()
            if bad:
                raise AppError(f"archive integrity check failed: {bad}")
        temp.replace(output)
    finally:
        if temp.exists():
            temp.unlink()
    print(f"Created {output} ({data['id']} {data['version']})")
    return 0


def inspect_command(args: argparse.Namespace) -> int:
    package = Path(args.package)
    with zipfile.ZipFile(package, "r") as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise AppError("package contains duplicate archive paths")
        if MANIFEST not in names:
            raise AppError(f"package does not contain {MANIFEST}")
        for name in names:
            safe_relative(name, "archive entry")
            info = archive.getinfo(name)
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                raise AppError(f"package contains a symlink: {name}")
        import tempfile
        with tempfile.TemporaryDirectory(prefix="glitch-inspect-") as temporary:
            root = Path(temporary)
            for name in names:
                destination = root.joinpath(*PurePosixPath(name).parts)
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(name))
            data, files = load_app(root)
            expected = {MANIFEST, *(relative for relative, _ in files)}
            if set(names) != expected:
                raise AppError("archive contents do not exactly match manifest files")
    print(f"Valid package: {data['name']} ({data['id']})")
    print(f"Version: {data['version']} | Files: {len(files)}")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="glitch", description="GLITCH//CORE application SDK")
    sub = result.add_subparsers(dest="command", required=True)
    validate = sub.add_parser("validate", help="validate an app source directory")
    validate.add_argument("app")
    validate.set_defaults(handler=validate_command)
    pack = sub.add_parser("pack", help="create a .gcpkg application archive")
    pack.add_argument("app")
    pack.add_argument("-o", "--output", required=True)
    pack.set_defaults(handler=pack_command)
    inspect = sub.add_parser("inspect", help="validate an existing .gcpkg archive")
    inspect.add_argument("package")
    inspect.set_defaults(handler=inspect_command)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        return args.handler(args)
    except (AppError, OSError, zipfile.BadZipFile, KeyError) as exc:
        print(f"glitch: error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
