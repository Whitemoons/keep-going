# Keep Going

맥북 덮개를 닫아도 잠들지 않게 하는 메뉴바 앱. 메뉴바 아이콘을 클릭하고 Touch ID로
확인하면 켜지고, 다시 클릭하면 꺼진다.

내부적으로는 `pmset -a disablesleep 1|0`을 루트 헬퍼가 대신 실행한다.

> 켜둔 채로 가방에 넣으면 발열·배터리 방전 위험이 있다.

## 구조

| 구성 | 역할 |
|---|---|
| `Sources/KeepGoing` | 메뉴바 앱. Touch ID 확인 후 헬퍼에 요청 |
| `Sources/KeepGoingHelper` | `SMAppService`로 등록되는 루트 LaunchDaemon. 켜기/끄기만 수행하고, 같은 팀 ID로 서명된 Keep Going 앱의 요청만 받는다 |
| `Sources/KeepGoingShared` | XPC 프로토콜과 식별자 |

macOS 13 이상, Apple Silicon/Intel 유니버설.

## 빌드

```bash
make app                 # build/Keep Going.app
make dmg                 # dist/KeepGoing.dmg
make lint
```

서명 인증서는 `SIGN_ID`로 바꾼다 (기본값 `Apple Development`). 헬퍼는 팀 ID가 있는
서명이 필요해서 ad-hoc 서명(`-`)으로는 동작하지 않는다.

배포용:

```bash
xcrun notarytool store-credentials keep-going   # 최초 1회
make notarize SIGN_ID="Developer ID Application: <이름> (<팀 ID>)"
```

## 사용

1. DMG에서 `Keep Going`을 Applications로 옮기고 실행한다.
2. 처음 클릭하면 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램에서 백그라운드
   실행을 허용한다 (최초 1회).
3. 왼쪽 클릭: 켜기/끄기. 오른쪽 클릭: 메뉴.

제거는 메뉴의 **제거…**를 쓴다. 잠자기 방지를 끄고 헬퍼 등록을 해제한다.
