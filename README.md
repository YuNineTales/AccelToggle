# AccelToggle

메뉴 막대에서 클릭 한 번으로 크로미움 계열 브라우저(Chrome, Edge, Brave, Vivaldi)의 **하드웨어 가속을 켜고 끄는** macOS 앱.

하드웨어 가속이 켜져 있으면 일부 DRM 스트리밍(예: 라프텔)이 Sidecar나 외부 화면에서 **소리만 나오고 화면은 검게** 나올 때가 있어. 그럴 때 가속을 끄면 화면이 나와.

| 아이콘 | 상태 |
|---|---|
| ⚡ `bolt.fill` | 하드웨어 가속 켜짐 (일반 모드) |
| 🎞 `film` | 하드웨어 가속 꺼짐 (DRM 시청 모드) |
| 🔄 | 브라우저 재시작 중 |
| ❔ | 지원하는 브라우저가 설치돼 있지 않음 |

## 요구 사항

- macOS 13 이상
- Xcode Command Line Tools (`xcode-select --install`)

## 빌드 & 설치

```bash
./build.sh
```

```bash
mv AccelToggle.app /Applications/
```

```bash
open /Applications/AccelToggle.app
```

Dock 아이콘 없이 메뉴 막대에만 아이콘이 떠.

### ⚠️ 전체 디스크 접근 권한 (필수)

브라우저 설정 파일(`~/Library/Application Support/Google/Chrome/Local State` 등)은 macOS가 보호하고 있어서, 권한이 없으면 앱이 값을 못 읽어. 이때 아이콘은 실제 값과 상관없이 ⚡로 보이고, 토글도 안 돼.

1. **시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한**
2. `+`로 `/Applications/AccelToggle.app` 추가 후 켜기
3. 메뉴 막대에서 AccelToggle을 종료했다가 다시 실행

> **서명과 권한 유지**: `build.sh`는 키체인에 `Apple Development` 인증서가 있으면 그걸로 서명해. 이 경우 다시 빌드해도 권한이 유지돼. 다른 인증서를 쓰려면 `SIGN_IDENTITY="인증서 이름" ./build.sh`로 지정하면 돼.
>
> 인증서가 없으면 ad-hoc 서명으로 빌드돼. 그러면 다시 빌드할 때마다 macOS가 다른 앱으로 인식해서 "설정 파일(Local State)을 못 읽었어" 알림이 떠. 이때는 목록에서 AccelToggle을 `−`로 빼고 다시 추가해줘. 서명 방식을 바꾼 직후에도 한 번은 이렇게 다시 추가해야 해.

## 사용법

- **왼쪽 클릭**: 대상 브라우저의 하드웨어 가속 토글
- **오른쪽 클릭**: 메뉴
  - 현재 상태 (가속 켜짐/꺼짐, 브라우저 실행 여부)
  - 가속 끄기 / 켜기
  - **대상 브라우저**: 설치된 브라우저 중에서 선택
  - **Sidecar 연결 시 자동 전환**: Sidecar가 연결되면 가속 끄기, 끊기면 다시 켜기
  - **로그인 시 자동 실행**: `/Applications`에 있어야 동작
  - 종료

### 토글하면 일어나는 일

- **브라우저가 꺼져 있을 때**: 설정 파일만 바꿔. 다음에 브라우저를 켤 때 적용돼.
- **브라우저가 켜져 있을 때**:
  1. 브라우저를 정상 종료해 (Cmd+Q와 같음, 강제 종료 아님)
  2. `Local State`의 `hardware_acceleration_mode.enabled` 값을 바꿔
  3. 브라우저를 `--restore-last-session` 옵션으로 다시 실행해서 **열려 있던 탭/창을 복원**해

> 탭은 복원되지만 영상 재생 위치나 입력 중이던 내용이 살아나는지는 사이트마다 달라. 저장 안 한 입력이 있으면 토글 전에 저장해줘.

브라우저가 15초 안에 안 꺼지면(예: "종료하시겠습니까?" 확인 창) 알림을 띄우고 멈춰.

### Sidecar 자동 전환

화면 이름에 `sidecar`나 `ipad`가 들어있으면 Sidecar로 판단해. 앱을 실행한 시점의 연결 상태를 기준으로 **연결/해제가 바뀔 때만** 동작해. 이미 연결된 상태에서 옵션을 켰다면 한 번 끊었다 다시 연결해줘.

## 백업 & 되돌리기

처음 값을 바꿀 때 원본을 한 번만 백업해:

```
~/Library/Application Support/<브라우저 폴더>/Local State.acceltoggle-backup
```

현재 값은 `jq`로 볼 수 있어 (`jq`도 전체 디스크 접근 권한이 있는 터미널에서 실행해야 해):

```bash
jq '.hardware_acceleration_mode' ~/Library/Application\ Support/Google/Chrome/Local\ State
```

브라우저 자체 설정(`chrome://settings/system` → "가능한 경우 그래픽 가속 사용")으로 바꿔도 같은 값이야.

## 지원 브라우저

| 브라우저 | 번들 ID | 데이터 폴더 (`~/Library/Application Support/` 아래) |
|---|---|---|
| Google Chrome | `com.google.Chrome` | `Google/Chrome` |
| Google Chrome Beta | `com.google.Chrome.beta` | `Google/Chrome Beta` |
| Microsoft Edge | `com.microsoft.edgemac` | `Microsoft Edge` |
| Brave | `com.brave.Browser` | `BraveSoftware/Brave-Browser` |
| Vivaldi | `com.vivaldi.Vivaldi` | `Vivaldi` |

실제로 테스트한 건 Google Chrome뿐이야. 다른 크로미움 브라우저는 `main.swift`의 `allBrowsers`에 한 줄 추가하면 메뉴에 나타나.

## 삭제

1. 메뉴에서 **로그인 시 자동 실행**을 끄고 종료
2. `/Applications/AccelToggle.app` 삭제
3. 전체 디스크 접근 권한 목록에서 제거
4. (선택) 각 브라우저 폴더의 `Local State.acceltoggle-backup` 삭제

## 알려진 한계

- 설정 파일을 못 읽으면 "가속 켜짐"으로 표시해. 대부분 권한 문제야.
- 브라우저 프로필별 설정이 아니라 `Local State` 전체 값을 바꿔. 그래서 모든 프로필에 적용돼.
