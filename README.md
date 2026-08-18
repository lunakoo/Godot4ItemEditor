# Project Horn Game Data Editor

Godot 4 standalone Resource editor입니다. Project Root 또는 Data Root를
열어 `.tres`/`.res`를 재귀적으로 검색하고, Project Horn의 실제 Resource
스크립트는 원본 프로젝트 컨텍스트에서 안전하게 읽고 저장합니다.

## 실행

1. Godot 4.7로 이 프로젝트를 엽니다.
2. `ResourceEditor.tscn`을 실행합니다.
3. `프로젝트 열기`에서 `bbule-like` Project Root를 선택합니다. 또는
   `데이터 폴더`로 `data` 폴더를 직접 선택합니다.
4. 브라우저에서 타입과 파일을 선택하고 Inspector를 편집합니다.

Project Horn을 열면 UI가 `project_horn_bridge.gd`를 해당 프로젝트의
headless Godot 프로세스에서 실행합니다. 브리지가 `get_property_list()`와
`ResourceLoader`, `ResourceSaver`를 사용하므로 `.tres` 문자열 파서나
게임 런타임 의존성이 필요하지 않습니다. Godot 실행 파일은 기본적으로
현재 실행 중인 Godot를 사용하며, 필요할 때만 이 편집기 프로젝트의
`application/config/godot_path` 설정으로 명시할 수 있습니다.

## 기능

- 명시적 Resource 타입 레지스트리와 타입/ID/경로 검색
- `New`, `Load`, `Save`, `Save As`, `Duplicate`, `Delete`
- Save / Discard / Cancel dirty guard, Undo / Redo, 외부 파일 변경 감지
- `get_property_list()`와 export metadata 기반 Inspector
- primitive, enum, Vector2/3/4, Rect2, Color, 배열, 중첩 Resource, Resource 참조
- 프로젝트 전체 ID/참조/범위 검증 및 참조 중인 Resource 삭제 차단
- 기존 Dictionary 필드는 보존하며 읽기 전용으로 표시

Duplicate와 New는 저장 전까지 파일을 만들지 않습니다. 저장은 선택한
Project Root 밖으로 나가지 않으며, 검증 오류가 있으면 중단됩니다.

## 테스트

편집기 프로젝트의 standalone smoke test:

```text
godot --headless --path . --script res://tests/resource_editor_smoke.gd
```

실제 Project Horn을 대상으로 브리지와 UI dirty-discard 경로를 확인하려면:

```text
godot --headless --path . --script res://tests/resource_editor_bridge_smoke.gd -- "C:/path/to/bbule-like"
```

## 제한 및 호환성

현재 Project Horn이 리팩토링 중이므로 타입 레지스트리의 스크립트 경로는
그 프로젝트의 현재 구조를 기준으로 합니다. 목표 문서의 metadata 계약이
게임 코드에 추가되기 전까지 참조 필드는 이름 기반 호환 레지스트리를
사용합니다. ID 이름 변경에 따른 참조 자동 변경, 3D 맵 편집, 강제 삭제,
Dictionary 스키마 편집은 포함하지 않습니다.

구조와 프로세스 경계는 [docs/editor_architecture.md](docs/editor_architecture.md)에
정리되어 있습니다.
