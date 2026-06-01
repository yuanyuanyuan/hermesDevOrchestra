#!/usr/bin/env python3
"""Project discovery helpers extracted from orch-init."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any


def read_json(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def read_toml(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        import tomllib
    except ModuleNotFoundError:
        try:
            import tomli as tomllib
        except ModuleNotFoundError:
            return {}
    try:
        with path.open("rb") as fh:
            data = tomllib.load(fh)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def detect_tech_stack(project: Path) -> dict[str, Any]:
    stack: dict[str, Any] = {"languages": [], "frameworks": [], "package_managers": [], "versions": {}}
    files_checked = {
        "package.json": ("javascript", "npm/yarn"),
        "pyproject.toml": ("python", "poetry/pip"),
        "requirements.txt": ("python", "pip"),
        "setup.py": ("python", "setuptools"),
        "Cargo.toml": ("rust", "cargo"),
        "go.mod": ("go", "go-modules"),
        "Gemfile": ("ruby", "bundler"),
        "pom.xml": ("java", "maven"),
        "build.gradle": ("java", "gradle"),
        "composer.json": ("php", "composer"),
    }
    for fname, (lang, pm) in files_checked.items():
        if (project / fname).exists():
            if lang not in stack["languages"]:
                stack["languages"].append(lang)
            if pm not in stack["package_managers"]:
                stack["package_managers"].append(pm)

    all_deps: dict[str, str] = {}
    pj = read_json(project / "package.json") or {}
    all_deps.update({k.lower(): v for k, v in pj.get("dependencies", {}).items()})
    all_deps.update({k.lower(): v for k, v in pj.get("devDependencies", {}).items()})

    ppt = read_toml(project / "pyproject.toml")
    if ppt:
        def _norm_pkg(name: str) -> str:
            normalized = name.split("[")[0].strip().lower()
            for sep in ("==", ">=", "<=", ">", "<", "~="):
                if sep in normalized:
                    normalized = normalized.split(sep, 1)[0].strip()
                    break
            return normalized

        def _extract_ver(name: str) -> str:
            for sep in ("==", ">=", "<=", ">", "<", "~="):
                if sep in name:
                    return name.split(sep, 1)[1].strip()
            return ""

        def _dependency_version(spec: Any) -> str:
            if isinstance(spec, str):
                return _extract_ver(spec)
            if isinstance(spec, dict):
                version = spec.get("version")
                if isinstance(version, str):
                    return _extract_ver(version) or version.strip()
            return ""

        for dep in ppt.get("project", {}).get("dependencies", []):
            if isinstance(dep, str):
                all_deps[_norm_pkg(dep)] = _extract_ver(dep)
        for deps in ppt.get("project", {}).get("optional-dependencies", {}).values():
            if isinstance(deps, list):
                for dep in deps:
                    if isinstance(dep, str):
                        all_deps[_norm_pkg(dep)] = _extract_ver(dep)
        for name, spec in ppt.get("tool", {}).get("poetry", {}).get("dependencies", {}).items():
            if str(name).lower() == "python":
                continue
            all_deps[_norm_pkg(str(name))] = _dependency_version(spec)

    req_path = project / "requirements.txt"
    if req_path.exists():
        for line in req_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                for sep in ("==", ">=", "<=", ">", "<", "~="):
                    if sep in line:
                        pkg, ver = line.split(sep, 1)
                        all_deps[pkg.strip().lower()] = ver.strip()
                        break
                else:
                    all_deps[line.strip().lower()] = ""

    framework_map = {
        "next": "Next.js",
        "react": "React",
        "vue": "Vue",
        "express": "Express",
        "fastapi": "FastAPI",
        "django": "Django",
        "flask": "Flask",
        "rails": "Ruby on Rails",
        "spring-boot": "Spring Boot",
    }
    for dep_name, fw_name in framework_map.items():
        if dep_name in all_deps:
            stack["frameworks"].append(fw_name)
            ver = all_deps[dep_name]
            if ver:
                stack["versions"][fw_name.lower().replace(" ", "_").replace(".", "_")] = ver

    if pj.get("version"):
        stack["versions"]["project"] = pj["version"]
    if ppt.get("project", {}).get("version"):
        stack["versions"]["project"] = ppt["project"]["version"]
    elif isinstance(ppt.get("tool", {}).get("poetry", {}).get("version"), str):
        stack["versions"]["project"] = ppt["tool"]["poetry"]["version"]
    if (project / "Dockerfile").exists() or any(project.glob("**/Dockerfile")):
        stack["container_ready"] = True
    return stack


def detect_test_commands(project: Path) -> list[str]:
    candidates = []
    if (project / "Makefile").exists():
        text = (project / "Makefile").read_text(encoding="utf-8")
        for line in text.splitlines():
            if line.strip().startswith("test:"):
                candidates.append("make test")
                break
    if (project / "package.json").exists():
        pj = read_json(project / "package.json") or {}
        scripts = pj.get("scripts", {})
        if "test" in scripts:
            candidates.append("npm test")
    if (project / "pyproject.toml").exists():
        candidates.append("pytest")
    if not candidates:
        candidates.append("make test")
    return candidates


def detect_deploy_target(project: Path) -> str:
    if (project / "vercel.json").exists():
        return "static/vercel"
    if (project / "netlify.toml").exists():
        return "static/netlify"
    if (project / "fly.toml").exists():
        return "container/fly"
    if (project / "Dockerfile").exists():
        return "container/docker"
    if (project / "serverless.yml").exists() or (project / "serverless.yaml").exists():
        return "faas/serverless"
    if (project / "package.json").exists():
        return "static/nodejs"
    if (project / "pyproject.toml").exists() or (project / "requirements.txt").exists():
        return "container/python"
    return "unknown"


def detect_risk_flags(project: Path) -> list[str]:
    flags = []
    protected_files = [".env", ".env.local", ".env.production", "secrets.json", "id_rsa"]
    for pf in protected_files:
        if (project / pf).exists():
            flags.append(f"protected_target:{pf}")
    git_config = project / ".git" / "config"
    if git_config.exists():
        text = git_config.read_text(encoding="utf-8")
        if "url = git@github.com" in text:
            flags.append("protected_target:ssh_git_remote")
    return flags


def run_discovery(project: Path, start_time: float | None = None, max_seconds: int = 300) -> dict[str, Any]:
    if start_time is None:
        start_time = time.monotonic()
    stack = detect_tech_stack(project)
    test_cmds = detect_test_commands(project)
    deploy = detect_deploy_target(project)
    risks = detect_risk_flags(project)
    elapsed = time.monotonic() - start_time
    status = "complete"
    if elapsed > max_seconds:
        status = "partial"
    if not stack["languages"] and deploy == "unknown" and not risks:
        status = "unknown"
    return {
        "tech_stack": stack,
        "test_command": test_cmds[0] if test_cmds else "unknown",
        "test_commands": test_cmds,
        "deploy_target": deploy,
        "risk_flags": risks,
        "status": status,
        "discovery_seconds": round(elapsed, 2),
    }
