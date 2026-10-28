"""Bound JSON work before routing creator requests or draft documents."""
from __future__ import annotations

import json

MAX_REQUEST_DEPTH = 32
MAX_REQUEST_STRUCTURE = 250_000


class RequestJSONError(ValueError):
    """The request cannot enter the typed maker command boundary."""


def _pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise RequestJSONError('duplicate JSON key')
        result[key] = value
    return result


def _no_float(value: str) -> object:
    raise RequestJSONError('non-integer JSON number is not supported')


def _check_depth(text: str) -> None:
    depth = 0
    structure = 0
    quoted = escaped = False
    for character in text:
        if quoted:
            if escaped:
                escaped = False
            elif character == '\\':
                escaped = True
            elif character == '"':
                quoted = False
        elif character == '"':
            quoted = True
        elif character in '[{':
            structure += 1
            depth += 1
            if depth > MAX_REQUEST_DEPTH:
                raise RequestJSONError(f'JSON nesting exceeds {MAX_REQUEST_DEPTH}')
        elif character in ']}':
            depth -= 1
        elif character in ',:':
            structure += 1
        if structure > MAX_REQUEST_STRUCTURE:
            raise RequestJSONError(f'JSON structure exceeds {MAX_REQUEST_STRUCTURE} separators/containers')


def _check_strings(value: object) -> None:
    pending = [value]
    while pending:
        node = pending.pop()
        if isinstance(node, dict):
            pending.extend(node.keys())
            pending.extend(node.values())
        elif isinstance(node, list):
            pending.extend(node)
        elif isinstance(node, str) and any(0xD800 <= ord(char) <= 0xDFFF for char in node):
            raise RequestJSONError('Unicode surrogate is forbidden')


def decode_json(raw: bytes) -> object:
    """Decode bytes already capped by the caller, without echoing raw tokens."""
    try:
        text = raw.decode('utf-8', 'strict')
        _check_depth(text)
        value = json.loads(text, object_pairs_hook=_pairs, parse_float=_no_float,
                           parse_constant=_no_float)
        _check_strings(value)
        return value
    except (UnicodeDecodeError, ValueError, RecursionError) as error:
        raise RequestJSONError(str(error)[:240]) from None
