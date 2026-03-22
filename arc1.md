# Geobuk 코드베이스 리뷰 (2026-03-20, 4차)

## 전체 평가: A+

+2,013줄 추가. 커맨드 완성 엔진, 시스템 모니터, 복수 후보 suggestion 리스트까지 구현. 테스트도 928건(2파일) 동시 추가. 이전 리뷰 잔여 사항(`formatCost` 중복)도 해결됨.

---

## 이전 리뷰 잔여 사항 수정 현황

| 잔여 사항 | 상태 | 근거 |
|---------|------|------|
| M5. ContentView 비대 | 유지 | ~589줄, 24+ `@State` |
| M6. onSubmit 클로저 비대 | 유지 | 소켓 이중 감지 추가로 분기 더 늘어남 |
| M7. `abbreviatedPath` 잔여 | **유지** | `SidebarView`, `PaneTreeView`에 아직 남아있음 |
| M8. `formatCost` 분산 | **수정 완료** | `SessionFormatter.formatCost`로 5곳 모두 통합 확인 |
| L5. GeobukLogger DateFormatter | 유지 | 변경 없음 |

---

## 신규 추가 기능 리뷰

### CompletionProvider (Shared/CompletionProvider.swift) — 우수

**설계**: 히스토리 → 파일 경로 → 공통 명령어 → CWD 파일 순서의 우선순위 탐색. `suggestAll()`로 복수 후보 + `suggest()`로 인라인 힌트 단일 API.

**잘된 점**:
- 중복 제거 (`appendUnique` + `Set<String>`)
- 틸드 확장, 경로 분리 등 헬퍼가 `static`으로 테스트 가능하게 노출
- 최소 길이 2자 제한으로 불필요한 완성 방지
- `maxResults` 파라미터로 결과 크기 제한

**개선 제안**:
- **M9**: `filePathCandidates`에서 `FileManager.contentsOfDirectory`를 매 키 입력마다 호출. 큰 디렉토리(`/usr/lib` 등)에서 느려질 수 있음. 디바운싱이나 캐싱 고려
- **L7**: `commonCommands`에 `open`이 2번 포함되어 있음 (줄 15, 20)

### SystemMonitor (Shared/SystemMonitor.swift) — 우수

**설계**: `host_statistics`/`proc_pidinfo`/`sysctl`/`getifaddrs` 네이티브 Darwin API 사용. 3초 폴링, 포트는 30초마다. 프로세스 통계는 `Task.detached`로 백그라운드 처리.

**잘된 점**:
- CPU 델타 기반 사용률 (누적값이 아닌 구간 사용률)
- 시스템 프로세스 필터링 (`systemProcessNames`)
- `nonisolated static` 메서드로 테스트 가능하게 설계
- `parsePsOutput`/`parseLsofPortOutput`이 파싱 로직과 I/O를 분리

**개선 제안**:
- **M10**: `fetchProcessStats()`가 모든 PID를 순회하며 `proc_pidinfo`를 호출 — 시스템 프로세스 수가 수백 개이므로 3초마다 실행 시 부담. top 10만 필요하므로 early termination이나 샘플링 고려
- **L8**: `parsePsOutput` 메서드가 남아있지만 `fetchProcessStats`로 네이티브 전환됨. `parsePsOutput`은 테스트에서만 사용 — dead code에 가까움

### BlockInputBar 확장 — 양호

**설계**: 인라인 힌트(Fish 스타일) + 복수 후보 리스트(VS Code 스타일) 하이브리드. Tab으로 수락, 위/아래로 탐색, Esc로 닫기.

**잘된 점**:
- 단일 `updateCompletions()` 호출로 힌트 + 리스트 동시 갱신
- `confirmedSelection`으로 방향키 선택과 Enter 제출 분리
- 후보 1개면 인라인 힌트만, 2개 이상이면 리스트 표시

**개선 제안**:
- **M11**: `updateCompletions`가 `onChange`마다 동기적으로 `FileManager.contentsOfDirectory`를 호출 (CompletionProvider 경유). 빠른 타이핑 시 메인 스레드 블로킹 가능. `Task` + debounce 패턴 권장

---

## 문제점 정리

### Medium (잔여 + 신규)

| ID | 설명 | 위치 |
|----|------|------|
| M5 | ContentView 비대 (~589줄, 24+ @State) | `ContentView.swift` |
| M6 | onSubmit 클로저 비대 (~50줄) | `SplitContainerView.swift:126-165` |
| M7 | `abbreviatedPath` 로컬 함수 잔여 | `SidebarView.swift`, `PaneTreeView.swift` |
| M9 | 파일 완성 시 매 입력마다 디렉토리 읽기 | `CompletionProvider.filePathCandidates` |
| M10 | `fetchProcessStats()` 전체 PID 순회 부담 | `SystemMonitor.swift:241-278` |
| M11 | 완성 제공자가 동기적으로 메인 스레드에서 I/O | `BlockInputBar.updateCompletions` |

### Low (잔여 + 신규)

| ID | 설명 | 위치 |
|----|------|------|
| L5 | GeobukLogger DateFormatter | `GeobukLogger.swift:112` |
| L7 | `commonCommands`에 `open` 중복 | `CompletionProvider.swift:15,20` |
| L8 | `parsePsOutput` 사실상 미사용 (테스트 전용) | `SystemMonitor.swift:280-299` |

---

## 테스트 리뷰 (신규)

### CompletionProviderTests (568줄, ~50 tests) — 우수

Suite 구조화가 훌륭: 최소 길이 → 히스토리 → 공통 명령어 → 파일 경로 → 우선순위 → CWD → 네거티브 → 퍼징. 특히:
- 특수문자/유니코드/제로폭 공백/BOM 등 퍼징 입력이 실전적
- `suggestAll` 테스트에서 중복 제거, 최대 결과 수, 혼합 소스 검증
- CWD 기반 완성이 `/usr`의 실제 파일 시스템으로 검증 (실환경 의존이나 합리적)

### SystemMonitorTests (360줄, ~30 tests) — 우수

- CPU 델타 계산의 경계값 (0/0, 100%, 매우 큰 값) 커버
- `parseLsofPortOutput` 파싱: 시스템 프로세스 필터링, 중복 제거, 정렬 검증
- 실제 시스템 호출 (`readTotalMemory`, `fetchProcessStats`) 검증
- 모델(`ProcessStat`, `PortInfo`)의 `Sendable` 준수 검증

### 누락된 테스트

- **BlockInputBar 통합** — `updateCompletions` → suggestion 리스트/인라인 힌트 표시 로직
- **ClaudePricingManager** — HTML 파싱 (이전부터 누락)
- **GeobukLogger** — 로테이션 (이전부터 누락)

---

## 아키텍처 코멘트

### 완성 엔진 설계

```
키 입력 → BlockInputBar.updateCompletions()
  → CompletionProvider.suggestAll()
    → (1) History: commands.reversed().filter(hasPrefix)
    → (2) FilePath: FileManager.contentsOfDirectory (/ 또는 ~ 포함 시)
    → (3) CommonCommands: static list filter
    → (4) CWD Files: FileManager.contentsOfDirectory
  → 중복 제거 → maxResults 제한
  → completionHint (인라인) + suggestions (리스트)
```

깔끔한 우선순위 설계. 다만 **모든 경로가 동기적**이므로, `/usr/lib` 같은 큰 디렉토리에서 체감 지연이 발생할 수 있음. `Task.detached` + 100ms debounce가 적절한 해결책.

### 시스템 모니터 아키텍처

```
SystemMonitor (3초 폴링)
  → CPU: host_statistics (Mach API) — 델타 기반
  → Memory: host_statistics64 (vm_statistics) + sysctl (hw.memsize)
  → Network: getifaddrs (en0 바이트 카운터)
  → Processes: proc_listallpids + proc_pidinfo (네이티브)
  → Ports: lsof (30초마다, 외부 프로세스)
```

포트 감지만 `lsof` 외부 프로세스를 사용하는 것은 합리적 — `libproc`으로 리스닝 포트를 직접 읽는 것은 복잡하고 `lsof`가 30초마다면 부담 없음.

### 전체 건강도 요약

| 영역 | 상태 | 변화 |
|------|------|------|
| C API 통합 (Ghostty) | 우수 | — |
| 블록 입력 모드 | 우수 | 완성 엔진 추가로 크게 개선 |
| Claude 모니터링 | 양호 | — |
| 시스템 모니터 | 우수 (신규) | 네이티브 API + 테스트 충실 |
| 테스트 | 우수 | +928줄, 퍼징 포함 |
| 코드 중복 | 양호 → 우수 | `formatCost` 통합 완료 |
| ContentView 복잡도 | 보통 | 변화 없음 |
| 성능 | 주의 필요 | 완성 제공자 동기 I/O (M9/M11) |
