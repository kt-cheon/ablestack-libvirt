# ABLestack libvirt RPM customization

이 저장소는 libvirt와 같은 업스트림 RPM을 커스터마이징할 때, `SRPM` 자체는 Git에서 관리하지 않고 최신 버전을 외부에서 내려받아 재구성하는 운영 방식을 표준화하기 위한 레포입니다.

## 기본 정책

- Git에는 커스텀 사양(`spec`)과 패치, 빌드 스크립트만 보관합니다.
- 최신 `src.rpm`은 `dnf download --source` 또는 배포 저장소에서 가져와 `.cache/srpm/` 아래에 저장합니다.
- 생성된 빌드 산출물과 SRPM은 Git 추적 대상에서 제외합니다.
- 실제 커스터마이징은 `specs/*.spec` 와 `patches/*.patch` 로 관리합니다.

## 저장소 구조

```text
.
├── README.md
├── .gitignore
├── specs/
│   └── libvirt.spec
├── patches/
│   └── 0001-ablestack-customization.patch
├── scripts/
│   ├── download_latest_srpm.sh
│   └── build_custom_rpm.sh
├── .cache/
│   └── srpm/         # 다운로드된 최신 SRPM 보관용 (git ignored)
├── rpmbuild/         # 빌드 결과물 및 산출물 (git ignored)
└── sources/          # 필요 시 추가 소스 파일 보관용
```

## 동작 방식

1. 최신 upstream SRPM을 다운로드합니다.
2. SRPM 안의 원본 소스와 spec 정보를 추출하여 커스텀 작업을 수행합니다.
3. `Release` 값을 커스텀 값으로 변경하고 필요한 패치를 적용합니다.
4. 결과물은 `rpmbuild/RPMS` 또는 `rpmbuild/SRPMS` 아래에 생성합니다.
5. Git에는 커스터마이징된 규격과 스크립트만 남기고, SRPM/빌드 산출물은 제외합니다.

## 빠른 시작

```bash
# 최신 SRPM 다운로드
./scripts/download_latest_srpm.sh libvirt

# 커스텀 RPM 빌드
./scripts/build_custom_rpm.sh
```

## 주의사항

- `dnf` 또는 `yum` 저장소가 `source` 패키지를 제공해야 합니다.
- 실제 운영 환경에서는 Red Hat/CentOS Stream 또는 EPEL 등의 소스 저장소를 활성화해 두는 것이 좋습니다.
- `Release` 값은 배포 정책에 맞게 변경해야 합니다. 예: `1.ablestack`, `2.ablestack` 등으로 versioning 합니다.

## 권장 운영 규칙

- upstream SRPM은 Git 저장소에 커밋하지 않습니다.
- 커스텀 작업은 패치 파일과 spec 변경으로 남깁니다.
- 자동화가 필요한 경우 CI에서 최신 SRPM을 받아서 `build_custom_rpm.sh` 를 실행하도록 구성합니다.
