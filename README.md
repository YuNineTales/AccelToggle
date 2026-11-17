# AccelToggle

메뉴 막대에서 클릭 한 번으로 크로미움 계열 브라우저(Chrome, Edge, Brave, Vivaldi)의 **하드웨어 가속을 켜고 끄는** macOS 앱입니다.

하드웨어 가속이 켜져 있으면 일부 DRM 스트리밍 서비스(예: 라프텔)가 Sidecar나 외부 화면에서 **소리만 나오고 화면은 검게** 표시되는 경우가 있습니다. 이때 하드웨어 가속을 끄면 화면이 정상적으로 표시됩니다.

| 아이콘 | 상태 |
|---|---|
| ⚡ `bolt.fill` | 하드웨어 가속 켜짐 (일반 모드) |
| 🎞 `film` | 하드웨어 가속 꺼짐 (DRM 시청 모드) |
| 🔄 | 브라우저 재시작 중 |
| ❔ | 지원하는 브라우저가 설치되어 있지 않음 |

## 요구 사항

- macOS 13 이상 (Apple Silicon, Intel 모두 지원)
- 직접 빌드하는 경우에만: Xcode Command Line Tools (`xcode-select --install`)

## 설치 (빌드된 앱 내려받기)

개발 도구 없이 바로 사용하려면 이 방법을 사용하십시오.

1. [Releases](https://github.com/YuNineTales/AccelToggle/releases/latest) 페이지에서 `AccelToggle-<버전>.zip`을 내려받습니다.
2. 압축을 풀고 `AccelToggle.app`을 **응용 프로그램** 폴더로 옮깁니다.
3. `AccelToggle.app`을 실행합니다.
4. 아래 **전체 디스크 접근 권한 (필수)** 항목에 따라 권한을 부여합니다.

### 처음 실행할 때 "열 수 없습니다" 경고가 표시되는 경우

이 앱은 Apple의 공증(notarization)을 받지 않았기 때문에, 인터넷에서 내려받은 경우 macOS가 처음 실행을 차단합니다.

1. 경고 창을 닫습니다.
2. **시스템 설정 → 개인정보 보호 및 보안**의 아래쪽에서 AccelToggle 항목의 **그래도 열기**를 누릅니다.
3. 다시 표시되는 창에서 **열기**를 누릅니다.

macOS 버전에 따라 위 버튼이 보이지 않거나 "손상되었기 때문에 열 수 없습니다"라고 표시될 수 있습니다. 이 경우 터미널에서 다음 명령을 실행한 뒤 다시 열어 보십시오.

```bash
xattr -dr com.apple.quarantine /Applications/AccelToggle.app
```

### 새 버전으로 업데이트할 때

배포용 앱은 ad-hoc 서명이므로, 새 버전으로 교체하면 macOS가 다른 앱으로 인식합니다. 업데이트 후에는 위의 "그래도 열기" 과정과 전체 디스크 접근 권한 부여(목록에서 `−`로 제거 후 다시 추가)를 한 번 더 진행하십시오.

## 직접 빌드 및 설치

```bash
./build.sh
```

```bash
mv AccelToggle.app /Applications/
```

```bash
open /Applications/AccelToggle.app
```

실행하면 Dock 아이콘 없이 메뉴 막대에만 아이콘이 표시됩니다.

### ⚠️ 전체 디스크 접근 권한 (필수)

브라우저 설정 파일(`~/Library/Application Support/Google/Chrome/Local State` 등)은 macOS의 보호를 받기 때문에, 권한이 없으면 앱이 값을 읽을 수 없습니다. 이 경우 아이콘은 실제 값과 관계없이 ⚡로 표시되며 토글도 동작하지 않습니다.

1. **시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한**을 엽니다.
2. `+` 버튼으로 `/Applications/AccelToggle.app`을 추가한 뒤 켭니다.
3. 메뉴 막대에서 AccelToggle을 종료한 후 다시 실행합니다.

> **서명과 권한 유지**: `build.sh`는 키체인에 `Apple Development` 인증서가 있으면 해당 인증서로 서명합니다. 이 경우 다시 빌드해도 권한이 유지됩니다. 다른 인증서를 사용하려면 `SIGN_IDENTITY="인증서 이름" ./build.sh`와 같이 지정하십시오.
>
> 배포용 zip은 `./build.sh --release`로 만듭니다. 이때는 인증서에 포함된 개인정보(이름·이메일·팀 ID)가 앱에 들어가지 않도록 항상 ad-hoc으로 서명합니다. 버전은 `VERSION=1.0.1 ./build.sh --release`와 같이 지정합니다.
>
> 인증서가 없으면 ad-hoc 서명으로 빌드됩니다. 이 경우 다시 빌드할 때마다 macOS가 다른 앱으로 인식하여 "설정 파일(Local State)을 읽을 수 없습니다" 알림이 표시됩니다. 이때는 목록에서 AccelToggle을 `−` 버튼으로 제거한 뒤 다시 추가하십시오. 서명 방식이 바뀐 직후에도 한 번은 이와 같이 다시 추가해야 합니다.

## 사용 방법

- **왼쪽 클릭**: 대상 브라우저의 하드웨어 가속을 토글합니다.
- **오른쪽 클릭**: 메뉴를 엽니다.
  - 현재 상태 (가속 켜짐/꺼짐, 브라우저 실행 여부)
  - 가속 끄기 / 켜기
  - **대상 브라우저**: 설치된 브라우저 중에서 선택합니다.
  - **Sidecar 연결 시 자동 전환**: Sidecar가 연결되면 가속을 끄고, 연결이 해제되면 다시 켭니다.
  - **로그인 시 자동 실행**: 앱이 `/Applications`에 있어야 동작합니다.
  - 종료

### 토글 시 동작

- **브라우저가 꺼져 있는 경우**: 설정 파일만 변경합니다. 다음에 브라우저를 실행할 때 적용됩니다.
- **브라우저가 실행 중인 경우**:
  1. 브라우저를 정상 종료합니다 (Cmd+Q와 동일하며, 강제 종료하지 않습니다).
  2. `Local State`의 `hardware_acceleration_mode.enabled` 값을 변경합니다.
  3. 브라우저를 `--restore-last-session` 옵션으로 다시 실행하여 **열려 있던 탭과 창을 복원**합니다.

> 탭은 복원되지만, 영상 재생 위치나 입력 중이던 내용이 유지되는지는 사이트마다 다릅니다. 저장하지 않은 입력이 있다면 토글하기 전에 저장하십시오.

브라우저가 15초 안에 종료되지 않으면(예: 종료 확인 창이 표시된 경우) 알림을 띄우고 작업을 중단합니다.

### Sidecar 자동 전환

화면 이름에 `sidecar` 또는 `ipad`가 포함되어 있으면 Sidecar로 판단합니다. 앱을 실행한 시점의 연결 상태를 기준으로, **연결 상태가 바뀔 때만** 동작합니다. 이미 연결된 상태에서 이 옵션을 켰다면 연결을 한 번 해제했다가 다시 연결하십시오.

## 백업 및 복원

처음 값을 변경할 때 원본 파일을 한 번만 백업합니다.

```
~/Library/Application Support/<브라우저 폴더>/Local State.acceltoggle-backup
```

현재 값은 `jq`로 확인할 수 있습니다. 이때 터미널에도 전체 디스크 접근 권한이 필요합니다.

```bash
jq '.hardware_acceleration_mode' ~/Library/Application\ Support/Google/Chrome/Local\ State
```

브라우저 자체 설정(`chrome://settings/system` → "가능한 경우 그래픽 가속 사용")도 같은 값을 변경합니다.

## 지원 브라우저

| 브라우저 | 번들 ID | 데이터 폴더 (`~/Library/Application Support/` 하위) |
|---|---|---|
| Google Chrome | `com.google.Chrome` | `Google/Chrome` |
| Google Chrome Beta | `com.google.Chrome.beta` | `Google/Chrome Beta` |
| Microsoft Edge | `com.microsoft.edgemac` | `Microsoft Edge` |
| Brave | `com.brave.Browser` | `BraveSoftware/Brave-Browser` |
| Vivaldi | `com.vivaldi.Vivaldi` | `Vivaldi` |

실제로 테스트한 브라우저는 Google Chrome뿐입니다. 다른 크로미움 계열 브라우저는 `main.swift`의 `allBrowsers`에 한 줄을 추가하면 메뉴에 표시됩니다.

## 삭제 방법

1. 메뉴에서 **로그인 시 자동 실행**을 끄고 앱을 종료합니다.
2. `/Applications/AccelToggle.app`을 삭제합니다.
3. 전체 디스크 접근 권한 목록에서 AccelToggle을 제거합니다.
4. (선택) 각 브라우저 폴더의 `Local State.acceltoggle-backup` 파일을 삭제합니다.

## 알려진 제한 사항

- 설정 파일을 읽지 못하면 "가속 켜짐"으로 표시됩니다. 대부분 권한 문제가 원인입니다.
- 프로필별 설정이 아니라 `Local State` 전체의 값을 변경하므로, 모든 프로필에 적용됩니다.
