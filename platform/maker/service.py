"""Bounded local project service for the M10 maker.

This module owns the browser/filesystem boundary. Every saved or exported
project is consumed by the same trusted Content-0 loader used by runtime code.
"""
from __future__ import annotations

import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import threading
import time
import uuid
from typing import Any, Callable

from content.loader import ContentError, InfrastructureError, load_project
from content.world_limits import MAX_JSON_BYTES, MAX_TOTAL_BYTES
from .playtest import (FrozenPlaytestSnapshot, PlaytestError,
                       PlaytestUnavailable, freeze_project, start_playtest)
from .command_input import CommandInputError, parse_command
from .presentation_content import presentation_content
from .runtime_process import RuntimeProcessError, run_runtime
from content.m10_command_wire import M10Command, M10CommandWireError, encode_m10_commands
from .runtime_response import RuntimeResponse

_PROJECT_ID = re.compile(r"[a-f0-9]{32}\Z")
_SESSION_ID = re.compile(r"[a-f0-9]{32}\Z")
_DOC_PATH = re.compile(r"[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\.json\Z")
_MEDIA = {
    "image/x-portable-pixmap": ".ppm",
    "image/png": ".png",
    "audio/wav": ".wav",
}
MAX_DOCUMENTS_BYTES = MAX_JSON_BYTES * 64
MAX_ASSET_BYTES = min(MAX_TOTAL_BYTES, 8 * 1024 * 1024)
MAX_PLAYTEST_SESSIONS = 32
MAX_PLAYTEST_COMMANDS = 4096
PLAYTEST_SESSION_TTL_SECONDS = 3600.0


class _PlaytestSession:
    def __init__(self, snapshot: FrozenPlaytestSnapshot,
                 commands: tuple[M10Command, ...],
                 response: RuntimeResponse, presentation: dict[str, Any],
                 last_access: float) -> None:
        self.snapshot = snapshot
        self.commands = commands
        self.response = response
        self.presentation = presentation
        self.last_access = last_access


class MakerError(Exception):
    """A safe, user-facing service error."""

    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _no_float(value: str) -> Any:
    raise ValueError("non-integer JSON number is not supported")


def decode_request(raw: bytes, limit: int = MAX_DOCUMENTS_BYTES) -> Any:
    """Decode bounded strict JSON, rejecting duplicate keys and non-finite numbers."""
    if len(raw) > limit:
        raise MakerError("request-too-large", f"request exceeds {limit} bytes")
    try:
        text = raw.decode("utf-8", "strict")
        return json.loads(text, object_pairs_hook=_pairs, parse_float=_no_float,
                          parse_constant=_no_float)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise MakerError("invalid-json", f"request is not strict JSON: {exc}") from None


def _json_bytes(value: Any, file: str) -> bytes:
    stack = [value]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            if any(key in {"__proto__", "prototype", "constructor"} for key in node):
                raise MakerError("unsafe-key", f"{file}: document contains a forbidden object key")
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    try:
        raw = (json.dumps(value, ensure_ascii=False, allow_nan=False,
                          separators=(",", ":"), sort_keys=True) + "\n").encode("utf-8")
    except (TypeError, ValueError, UnicodeEncodeError) as exc:
        raise MakerError("invalid-document", f"{file}: document is not JSON-compatible ({exc})") from None
    if len(raw) > MAX_JSON_BYTES:
        raise MakerError("document-too-large", f"{file}: document exceeds {MAX_JSON_BYTES} bytes")
    return raw


def _doc_path(value: Any) -> str:
    if (not isinstance(value, str) or len(value) > 240 or not value.isascii()
            or not _DOC_PATH.fullmatch(value)
            or any(part in {".", ".."} for part in value.split("/"))):
        raise MakerError("path", "document path must be a normalized relative .json path")
    return value


class MakerService:
    """Manage maker projects under one trusted local root."""

    def __init__(self, root: os.PathLike[str] | str,
                 template_root: os.PathLike[str] | str | None = None,
                 runtime_path: os.PathLike[str] | str | None = None,
                 clock: Callable[[], float] = time.monotonic):
        self.root = Path(root).absolute()
        self.root.mkdir(parents=True, exist_ok=True)
        if self.root.is_symlink():
            raise MakerError("root", "project root may not be a symbolic link")
        self.template_root = Path(template_root or Path(__file__).resolve().parents[2] /
                                  "examples" / "m10-starter").absolute()
        self.runtime_path = (None if runtime_path is None else
                             Path(runtime_path).expanduser().absolute())
        self._clock = clock
        self._session_lock = threading.RLock()
        self._sessions: dict[str, _PlaytestSession] = {}
        self._session_reservations = 0

    def project_path(self, project_id: str) -> Path:
        if not isinstance(project_id, str) or not _PROJECT_ID.fullmatch(project_id):
            raise MakerError("project-id", "project id is invalid")
        path = self.root / project_id
        if path.is_symlink() or not path.resolve().is_relative_to(self.root.resolve()):
            raise MakerError("project-path", "project path escapes the configured root")
        if not path.is_dir():
            raise MakerError("not-found", "project was not found")
        return path

    def list_projects(self) -> dict[str, Any]:
        projects = []
        for path in sorted(self.root.iterdir()):
            if path.is_dir() and not path.is_symlink() and _PROJECT_ID.fullmatch(path.name):
                try:
                    project = self._project_payload(path.name)
                    projects.append({key: project[key] for key in ("id", "name", "projectId")})
                except MakerError:
                    continue
        return {"ok": True, "projects": projects}

    def create_project(self, name: str) -> dict[str, Any]:
        if not isinstance(name, str) or not name.strip() or len(name) > 128 or not name.isprintable():
            raise MakerError("name", "name must contain 1..128 printable characters")
        project_id = uuid.uuid4().hex
        stage = Path(tempfile.mkdtemp(prefix=".maker-create-", dir=self.root))
        try:
            shutil.copytree(self.template_root, stage, dirs_exist_ok=True)
            project_file = stage / "project.json"
            project = self._read_json(project_file)
            project["id"] = f"maker:p{project_id[:26]}"
            project["name"] = name.strip()
            project_file.write_bytes(_json_bytes(project, "project.json"))
            destination = self.root / project_id
            os.replace(stage, destination)
        except Exception:
            shutil.rmtree(stage, ignore_errors=True)
            raise
        return {"ok": True, "project": self._project_payload(project_id)}

    def open_project(self, project_id: str) -> dict[str, Any]:
        return {"ok": True, "project": self._project_payload(project_id)}

    def save_documents(self, project_id: str, documents: Any) -> dict[str, Any]:
        if not isinstance(documents, dict) or not documents:
            raise MakerError("documents", "documents must be a non-empty object")
        normalized = {_doc_path(path): value for path, value in documents.items()}
        payloads = {path: _json_bytes(value, path) for path, value in normalized.items()}
        if sum(map(len, payloads.values())) > MAX_DOCUMENTS_BYTES:
            raise MakerError("documents-too-large", "document bundle exceeds the service limit")
        path = self.project_path(project_id)
        self._replace_tree(path, lambda stage: self._replace_documents(stage, payloads))
        return {"ok": True, "project": self._project_payload(project_id), "saved": True}

    def import_asset(self, project_id: str, path: str, media_type: str,
                     content_base64: str, asset_id: str | None = None) -> dict[str, Any]:
        if media_type not in _MEDIA:
            raise MakerError("media-type", "asset media type must be PNG, PPM, or WAV")
        if not isinstance(path, str) or not path.startswith("assets/") or len(path) > 240:
            raise MakerError("path", "asset path must be a relative path under assets/")
        normalized = path.split("/")
        if any(p in {"", ".", ".."} or not re.fullmatch(r"[A-Za-z0-9_.-]+", p) for p in normalized):
            raise MakerError("path", "asset path must use normalized safe components")
        if not path.endswith(_MEDIA[media_type]):
            raise MakerError("path", "asset suffix does not match media type")
        if not isinstance(content_base64, str) or len(content_base64) > (MAX_ASSET_BYTES * 4 // 3 + 8):
            raise MakerError("asset-too-large", "encoded asset exceeds the service limit")
        try:
            raw = base64.b64decode(content_base64, validate=True)
        except (binascii.Error, ValueError):
            raise MakerError("asset-encoding", "asset content must be valid base64") from None
        if not raw or len(raw) > MAX_ASSET_BYTES:
            raise MakerError("asset-size", f"asset must contain 1..{MAX_ASSET_BYTES} bytes")
        project_dir = self.project_path(project_id)
        manifest = self._read_json(project_dir / "manifest.json")
        assets = manifest.get("assets")
        if not isinstance(assets, list):
            raise MakerError("manifest", "manifest assets must be an array")
        chosen_id = asset_id or f"maker:asset-{uuid.uuid4().hex[:16]}"
        if not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}:[a-z][a-z0-9_-]{0,31}", chosen_id):
            raise MakerError("asset-id", "asset id must be lowercase namespace:local")
        if any(isinstance(item, dict) and (item.get("id") == chosen_id or item.get("path") == path) for item in assets):
            raise MakerError("duplicate-asset", "asset id or path already exists")
        assets.append({"id": chosen_id, "path": path, "mediaType": media_type,
                       "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
        manifest_bytes = _json_bytes(manifest, "manifest.json")
        self._replace_tree(project_dir, lambda stage: self._write_documents(
            stage, {"manifest.json": manifest_bytes, path: raw}))
        return {"ok": True, "project": self._project_payload(project_id), "assetId": chosen_id}

    def validate_project(self, project_id: str) -> dict[str, Any]:
        path = self.project_path(project_id)
        try:
            loaded = load_project(path)
        except ContentError as exc:
            return {"ok": True, "valid": False,
                    "diagnostics": [diagnostic.as_dict() for diagnostic in exc.diagnostics]}
        except (InfrastructureError, OSError) as exc:
            raise MakerError("validation-infrastructure", str(exc)) from None
        extra_documents = self._unmanifested_documents(path)
        if extra_documents:
            return {"ok": True, "valid": False, "diagnostics": extra_documents}
        return {"ok": True, "valid": True, "projectId": str(loaded.project.id),
                "contentHash": loaded.content_hash,
                "counts": {"assets": len(loaded.assets), "species": len(loaded.species),
                           "encounters": len(loaded.encounters), "maps": len(loaded.maps),
                           "items": len(loaded.items), "shops": len(loaded.shops),
                           "events": len(loaded.events), "trainers": len(loaded.trainers),
                           "dialogues": len(loaded.dialogues)}}

    def export_project(self, project_id: str) -> dict[str, Any]:
        source = self.project_path(project_id)
        stage = Path(tempfile.mkdtemp(prefix=".maker-export-", dir=self.root))
        export_root = self.root / "exports"
        export_root.mkdir(exist_ok=True)
        try:
            shutil.copytree(source, stage, dirs_exist_ok=True)
            loaded = load_project(stage)
            extra_documents = self._unmanifested_documents(stage)
            if extra_documents:
                shutil.rmtree(stage, ignore_errors=True)
                return {"ok": True, "valid": False, "diagnostics": extra_documents}
            target = export_root / f"{project_id}-{loaded.content_hash}"
            if target.exists() or target.is_symlink():
                if target.is_symlink() or not target.is_dir():
                    raise MakerError("export-existing-invalid", "existing export path is not a project directory")
                existing = load_project(target)
                if (existing.content_hash != loaded.content_hash or
                        str(existing.project.id) != str(loaded.project.id) or
                        self._unmanifested_documents(target)):
                    raise MakerError("export-existing-invalid", "existing export does not match the validated snapshot")
                shutil.rmtree(stage)
            else:
                os.replace(stage, target)
        except ContentError as exc:
            shutil.rmtree(stage, ignore_errors=True)
            return {"ok": True, "valid": False,
                    "diagnostics": [diagnostic.as_dict() for diagnostic in exc.diagnostics]}
        except (InfrastructureError, OSError) as exc:
            shutil.rmtree(stage, ignore_errors=True)
            raise MakerError("export", str(exc)) from None
        except MakerError:
            shutil.rmtree(stage, ignore_errors=True)
            raise
        return {"ok": True, "valid": True, "projectId": str(loaded.project.id),
                "contentHash": loaded.content_hash, "exportPath": str(target)}

    def playtest_project(self, project_id: str, rng_state: list[int], wait_ticks: int,
                         expected_content_hash: str) -> dict[str, Any]:
        """Freeze exact validated input before handing it to the compiled runtime."""
        if not isinstance(expected_content_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_content_hash):
            raise MakerError("content-hash", "playtest requires the full validated content hash")
        reserved = self.runtime_path is not None
        if reserved:
            self._reserve_session_slot()
        try:
            validation = self.validate_project(project_id)
            if not validation["valid"]:
                raise MakerError("playtest-invalid", "project failed shipping validation; validate the draft")
            if validation["contentHash"] != expected_content_hash:
                raise MakerError("content-mismatch", "draft changed since validation; validate again")
            exported = self.export_project(project_id)
            if not exported["valid"]:
                raise MakerError("playtest-invalid", "project changed during export; validate again")
            if exported["contentHash"] != expected_content_hash:
                raise MakerError("content-mismatch", "draft changed since validation; validate again")
            snapshot = freeze_project(exported["exportPath"],
                                      rng_state=tuple(rng_state) if isinstance(rng_state, list) else rng_state,
                                      wait_ticks=wait_ticks)
            if snapshot.content_hash != expected_content_hash:
                raise MakerError("content-mismatch", "frozen export changed since validation; validate again")
            if self.runtime_path is None:
                return start_playtest(snapshot)
            response = run_runtime(snapshot, (), executable_path=self.runtime_path)
            if response.status != "accepted" or response.accepted_commands != 0:
                raise MakerError("playtest-runtime-rejected", "compiled runtime rejected the frozen project")
            presentation = presentation_content(snapshot)
            session_id = uuid.uuid4().hex
            record = _PlaytestSession(snapshot, (), response, presentation,
                                      self._clock())
            with self._session_lock:
                self._prune_sessions_locked()
                if session_id in self._sessions:
                    raise MakerError("playtest-session", "could not allocate a playtest session")
                self._sessions[session_id] = record
                self._session_reservations -= 1
                reserved = False
            return self._session_payload(session_id, record)
        except PlaytestUnavailable as exc:
            raise MakerError("playtest-unavailable", str(exc)) from None
        except RuntimeProcessError as exc:
            raise MakerError("playtest-runtime", str(exc)) from None
        except PlaytestError as exc:
            raise MakerError("playtest-invalid", str(exc)) from None
        finally:
            if reserved:
                with self._session_lock:
                    self._session_reservations -= 1

    def step_playtest(self, session_id: str, command: object,
                      expected_commands: int) -> dict[str, Any]:
        """Replay one typed candidate and commit it only after runtime acceptance."""
        if (type(session_id) is not str or not _SESSION_ID.fullmatch(session_id)):
            raise MakerError("playtest-session", "playtest session ID is invalid")
        if (type(expected_commands) is not int or
                not 0 <= expected_commands <= MAX_PLAYTEST_COMMANDS):
            raise MakerError("playtest-sequence", "expectedCommands is outside the supported range")
        try:
            typed_command = (parse_command(command) if type(command) is dict
                             else command)
            encode_m10_commands((typed_command,))
        except (CommandInputError, M10CommandWireError) as exc:
            raise MakerError("playtest-command", str(exc)) from None
        with self._session_lock:
            self._prune_sessions_locked()
            record = self._sessions.get(session_id)
            if record is None:
                raise MakerError("playtest-session", "playtest session was not found or expired")
            if expected_commands != len(record.commands):
                raise MakerError("playtest-sequence", "expectedCommands does not match the accepted log")
            if len(record.commands) >= MAX_PLAYTEST_COMMANDS:
                raise MakerError("playtest-command-limit", "playtest command log reached 4096 commands")
            candidate = record.commands + (typed_command,)
            try:
                response = run_runtime(record.snapshot, candidate,
                                       executable_path=self.runtime_path)
            except (RuntimeProcessError, PlaytestUnavailable) as exc:
                raise MakerError("playtest-runtime", str(exc)) from None
            except PlaytestError as exc:
                raise MakerError("playtest-invalid", str(exc)) from None
            if (response.status in {"accepted", "encounter", "battle"} and
                    response.accepted_commands == len(candidate)):
                record.commands = candidate
                record.response = response
                record.last_access = self._clock()
                return self._session_payload(session_id, record)
            record.last_access = self._clock()
            return self._session_payload(session_id, record, rejected=True)

    def _reserve_session_slot(self) -> None:
        with self._session_lock:
            self._prune_sessions_locked()
            if len(self._sessions) + self._session_reservations >= MAX_PLAYTEST_SESSIONS:
                raise MakerError("playtest-session-limit", "at most 32 playtest sessions may be active")
            self._session_reservations += 1

    def _prune_sessions_locked(self) -> None:
        now = self._clock()
        expired = [key for key, value in self._sessions.items()
                   if now - value.last_access >= PLAYTEST_SESSION_TTL_SECONDS]
        for key in expired:
            del self._sessions[key]

    @staticmethod
    def _dialogue_payload(record: _PlaytestSession) -> dict[str, Any] | None:
        response = record.response
        if response.dialogue_closed:
            return None
        dialogues = record.presentation.get("dialogues", [])
        match = next((row for row in dialogues
                      if row["runtimeId"] == response.dialogue_id), None)
        if match is None or response.dialogue_line_index >= len(match["lines"]):
            raise MakerError("playtest-runtime", "runtime dialogue cursor is outside frozen content")
        line = match["lines"][response.dialogue_line_index]
        return {"id": response.dialogue_id,
                "lineIndex": response.dialogue_line_index,
                "speaker": line["speaker"], "text": line["text"]}

    @staticmethod
    def _session_payload(session_id: str, record: _PlaytestSession,
                         rejected: bool = False) -> dict[str, Any]:
        response = record.response
        if rejected:
            return {"ok": True, "sessionId": session_id,
                    "contentHash": record.snapshot.content_hash,
                    "status": "rejected",
                    "acceptedCommands": len(record.commands),
                    "sceneCsv": response.scene_csv,
                    "cuesCsv": "1,0", "encounterId": None,
                    "dialogue": MakerService._dialogue_payload(record),
                    "presentation": record.presentation, "rejected": True}
        return {"ok": True, "sessionId": session_id,
                "contentHash": record.snapshot.content_hash,
                "status": response.status,
                "acceptedCommands": response.accepted_commands,
                "sceneCsv": response.scene_csv,
                "cuesCsv": response.cues_csv,
                "encounterId": response.encounter_id,
                "dialogue": MakerService._dialogue_payload(record),
                "presentation": record.presentation}

    def _project_payload(self, project_id: str) -> dict[str, Any]:
        root = self.project_path(project_id)
        documents: dict[str, Any] = {}
        for path in sorted(root.rglob("*.json")):
            if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise MakerError("project-path", "project contains a symbolic link")
            rel = path.relative_to(root).as_posix()
            raw = path.read_bytes()
            if len(raw) > MAX_JSON_BYTES:
                raise MakerError("project-too-large", "project documents exceed the service limit")
            documents[rel] = self._decode_file(raw, rel)
            if sum(len(_json_bytes(value, file)) for file, value in documents.items()) > MAX_DOCUMENTS_BYTES:
                raise MakerError("project-too-large", "project documents exceed the service limit")
        project = documents.get("project.json", {})
        return {"id": project_id, "name": project.get("name", ""),
                "projectId": project.get("id", ""), "documents": documents}

    @staticmethod
    def _decode_file(raw: bytes, file: str) -> Any:
        try:
            return json.loads(raw.decode("utf-8", "strict"), object_pairs_hook=_pairs,
                              parse_float=_no_float, parse_constant=_no_float)
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            raise MakerError("invalid-project-json", f"{file}: project document is invalid JSON") from None

    def _read_json(self, path: Path) -> dict[str, Any]:
        if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_JSON_BYTES:
            raise MakerError("project-file", f"{path.name}: file is missing, unsafe, or too large")
        value = self._decode_file(path.read_bytes(), path.name)
        if not isinstance(value, dict):
            raise MakerError("project-file", f"{path.name}: expected an object")
        return value

    def _unmanifested_documents(self, root: Path) -> list[dict[str, Any]]:
        manifest = self._read_json(root / "manifest.json")
        referenced = {"project.json", "manifest.json"}
        for key in ("catalogs", "maps", "encounters", "moves", "mixRecipes",
                    "mixResults", "items", "shops", "events", "trainers", "dialogues"):
            values = manifest.get(key, [])
            if isinstance(values, list):
                referenced.update(value for value in values if isinstance(value, str))
        extras = []
        for path in sorted(root.rglob("*.json")):
            if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise MakerError("project-path", "project contains a symbolic link")
            relative = path.relative_to(root).as_posix()
            if relative not in referenced:
                extras.append({"code": "unmanifested-document", "file": relative,
                               "pointer": "", "entityId": None,
                               "message": "JSON document is not referenced by manifest.json"})
        return extras

    @staticmethod
    def _write_documents(stage: Path, payloads: dict[str, bytes]) -> None:
        for relative, payload in payloads.items():
            target = stage.joinpath(*relative.split("/"))
            if not target.resolve().is_relative_to(stage.resolve()):
                raise MakerError("path", "document path escapes the project")
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_symlink():
                raise MakerError("path", "cannot replace a symbolic link")
            fd, temporary = tempfile.mkstemp(prefix=".maker-write-", dir=target.parent)
            try:
                with os.fdopen(fd, "wb") as stream:
                    stream.write(payload)
                    stream.flush()
                    os.fsync(stream.fileno())
                os.replace(temporary, target)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)

    @classmethod
    def _replace_documents(cls, stage: Path, payloads: dict[str, bytes]) -> None:
        """Replace the complete JSON draft while retaining non-JSON assets."""
        keep = set(payloads)
        for existing in stage.rglob("*.json"):
            if existing.is_symlink() or not existing.resolve().is_relative_to(stage.resolve()):
                raise MakerError("project-path", "project contains a symbolic link")
            if existing.relative_to(stage).as_posix() not in keep:
                existing.unlink()
        for directory in sorted((path for path in stage.rglob("*") if path.is_dir()),
                                key=lambda path: len(path.parts), reverse=True):
            if not any(directory.iterdir()):
                directory.rmdir()
        cls._write_documents(stage, payloads)

    def _replace_tree(self, current: Path, mutate: Any) -> None:
        stage = Path(tempfile.mkdtemp(prefix=".maker-save-", dir=self.root))
        backup = self.root / f".maker-backup-{uuid.uuid4().hex}"
        try:
            shutil.copytree(current, stage, dirs_exist_ok=True)
            mutate(stage)
            os.replace(current, backup)
            try:
                os.replace(stage, current)
            except Exception:
                os.replace(backup, current)
                raise
            shutil.rmtree(backup)
        except Exception:
            shutil.rmtree(stage, ignore_errors=True)
            if backup.exists() and not current.exists():
                os.replace(backup, current)
            raise
