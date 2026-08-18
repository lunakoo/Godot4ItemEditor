# Project Horn Data Editor

Godot 4용 범용 Resource 편집기입니다. 게임 프로젝트의 실제 데이터 스키마와 분리된 테스트용 Resource를 기준으로 `.tres`와 `.res` 파일을 편집합니다.

## 기능

- 한글 UI
- 외부 작업 폴더 선택
- 하위 폴더까지 Resource 재귀 검색
- 파일명·상대 경로 검색
- New, Load, Save, Save As, Duplicate, Delete
- Save / Discard / Cancel 기반 Dirty State 처리
- `get_property_list()` 기반 Inspector 자동 생성
- String, int, float, bool, enum, Texture2D, PackedScene, Resource 필드 지원
- 타입·로드·저장 오류와 빈 문자열 검증

## 실행

1. Godot 4.3에서 프로젝트를 엽니다.
2. `ResourceEditor.tscn`을 실행합니다.
3. `폴더 열기`로 Resource 파일이 있는 작업 폴더를 선택합니다.
4. `테스트 리소스`를 선택하고 `새로 만들기`로 편집을 시작합니다.

## 범위

현재 등록된 Resource 타입은 `TestResource` 하나입니다. Project Horn의 HeroData, MonsterData, SkillData 스키마와 기존 Item 전용 구조는 포함하지 않습니다.

외부 게임 프로젝트를 마운트하거나 해당 프로젝트의 `res://` 의존성을 해석하지 않습니다.
