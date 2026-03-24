# Geobuk Roadmap

## 완료된 Phase

| Phase | 내용 | 버전 |
|-------|------|------|
| Phase 0 | 프로젝트 부트스트래핑 (Xcode + libghostty) | v0.1.0 |
| Phase 1 | 기본 터미널 에뮬레이션 (Metal GPU 렌더링) | v0.1.0 |
| Phase 2 | 패널 분할 (SplitTree, 드래그 리사이즈, Undo/Redo) | v0.1.0 |
| Phase 2.5 | Socket API + Headless Session (JSON-RPC 2.0) | v0.1.0 |
| Phase 3 | 사이드바 워크스페이스 + 세션 영속성 | v0.1.0 |
| Phase 4a | Claude stream-json 코어 파싱 | v0.1.0 |
| Phase 4b | Claude 세션 UI + Agent Team 모니터 | v0.1.0 |
| Phase 5 | 프로세스/포트 감시 + 명령어 완성 | v0.1.0 |
| Phase 6 | 알림 시스템 (macOS 알림 + 링 오버레이 + Dock 뱃지) | v0.1.0 |
| Phase 7 | Claude Code Team split-pane 통합 (iTerm2 shim) | v0.2.0 |

## Phase 7 상세 (v0.2.0)

Claude Code Agent Team의 split-pane 모드를 Geobuk 네이티브로 지원.

### 구현 내용
- **iTerm2 shim**: `it2` CLI 대체 스크립트 → Geobuk Socket API로 변환
- **팀원 미니 터미널**: 리더 패널 하단에 팀원 터미널을 임베드
- **확대/축소**: 팀원 클릭 → 리더 영역에 확대 표시, 입력 가능
- **자동 정리**: 팀원 종료 시 미니 터미널 자동 제거
- **단축키**: Esc (축소), Cmd+←/→ (팀원 전환)
- **Trust 방지**: `--dangerously-skip-permissions` 자동 추가
- **일반 셸**: 팀원 패널은 블록 모드 없이 일반 셸로 시작

### 대규모 팀 대응
- 1~3명: 미니 터미널 표시
- 4명+: 라벨 카드로 자동 전환 (수평 스크롤)

---

## 다음 Phase

### Phase 5.5: 셸 Tab 완성 캡처
> 우선순위: 높음

현재 `--help` 파싱으로 서브커맨드 수준(70%)만 커버. Headless PTY에서 Tab 키를 전송하여 셸의 completion 결과를 캡처하면 99% 커버리지 달성.

**주요 작업:**
- Headless PTY 생성 (Phase 2.5 인프라 활용)
- CWD 동기화 (사용자 셸과 동일 디렉토리)
- zsh/bash/fish 출력 파싱
- 디바운스 + 캐싱

### Phase 8: API 확장
> 우선순위: 중간

| API | 용도 |
|-----|------|
| `session.waitForPattern(name, regex, timeout)` | 출력 패턴 매칭 (폴링 제거) |
| `session.cost(name)` | 세션별 비용 조회 |
| `notify.send(pane, message)` | 프로그래밍 방식 알림 |

**장기 목표:**
- Claude Code CustomPaneBackend 프로토콜 지원 (GitHub Issue #26572)
- 공식 프로토콜 구현 시 iTerm2 shim → 네이티브 백엔드 전환

### Phase 9: 블록 렌더링 고도화
> 우선순위: 중간

현재 블록 입력 모드만 구현됨. 명령어 단위 블록 렌더링으로 확장:
- 블록 접기/펼치기 (긴 출력 축소)
- 블록 단위 복사/재실행/삭제
- 블록 간 검색
- 리사이즈 시 리플로우 없음 (SwiftUI re-layout)
- TUI 앱 자동 전환 (alternate screen 감지)

### Phase 10: 내장 브라우저
> 우선순위: 낮음

- WKWebView + NSViewRepresentable
- SplitTree에 BrowserPane 타입 추가
- localhost 포트 감지 → "Open in Browser" 자동 제안
- JS 실행 API, 콘솔 캡처

---

## 리팩토링 잔여 항목

| 항목 | 심각도 | 설명 |
|------|--------|------|
| C2 | Critical | GhosttySurfaceView surface 포인터 안전성 (use-after-free 위험) |
| H5 | High | ContentView → AppCoordinator 추출 (30+ @State 집중) |
| H6 | High | Timer → Task.sleep 교체 (leak 위험) |
| H7 | High | DockerPanelView readDataToEndOfFile 데드락 가능 |
| H8 | High | SystemMonitor cooperative thread pool 블로킹 |

현재 실사용에 영향을 주는 건 없으나, 기능 추가 시 H5(AppCoordinator)를 같이 진행 권장.

---

## 제품 품질 로드맵

### 단기 (v0.2.x)
- [ ] v0.2.0 릴리즈 (Phase 7 포함)
- [ ] README 업데이트 (Team 기능, 스크린샷)
- [ ] SHORTCUTS.md 업데이트 (Team 단축키)

### 중기 (v0.3.x)
- [ ] Apple Developer 계정 → 코드 서명 + 공증
- [ ] Homebrew Cask 등록 (`brew install --cask geobuk`)
- [ ] Sparkle 자동 업데이트 프레임워크

### 장기
- [ ] Claude Code CustomPaneBackend PR (Issue #26572)
- [ ] 멀티 AI 모델 지원 (Codex, Gemini CLI)
- [ ] 성능 벤치마크 CI (4, 8, 12, 16, 20 패널)
