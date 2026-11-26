# ABLESTACK libvirt RBD RPM

Rocky Linux의 최신 libvirt SRPM으로 Mold용 `libvirt-daemon-driver-storage-rbd` RPM을 빌드합니다. 소스 RPM과 빌드 산출물은 Git에서 제외합니다.

## 빌드

Podman이 설치된 Linux x86_64에서 실행합니다. 기본값은 실행 중인 Rocky Linux의 릴리스입니다.

```bash
git clone https://github.com/kt-cheon/ablestack-libvirt.git
cd ablestack-libvirt
./scripts/build_latest_rpm.sh
```

다른 릴리스를 빌드하려면 `./scripts/build_latest_rpm.sh 9.9`처럼 버전을 넘깁니다. 기본 빌드 병렬 작업 수는 6이며 `BUILD_JOBS`로 조절할 수 있습니다.

스크립트는 해당 Rocky Linux 컨테이너에서 AppStream 메타데이터를 새로 읽어 최신 SRPM을 받고, 같은 릴리스의 BaseOS, AppStream, CRB 저장소로 빌드 의존성을 설치합니다. 공식 배포 저장소에서 보관된 릴리스는 Vault를 조회합니다. 빌드와 libvirt 자체 테스트가 끝나면 마지막 `RPM:` 행에 결과 경로를 출력합니다. 로그는 각 실행 디렉터리의 `rpmbuild/run.*/build.log`에 있습니다.

## RBD 수정과 의존성

`patches/mold-rbd.patch`는 9.8 커스텀 RPM에서 복원했습니다. Glue v20.2.5의 `librados`가 지원하지 않는 `auth_supported` 설정 두 곳을 제거하며, Ceph 사용자와 키 설정은 유지합니다.

공식 SRPM의 spec과 패치를 사용합니다. upstream에서 이미 `auth_supported`를 제거한 경우 그 소스로 계속 빌드합니다. 소스나 spec 변경으로 패치를 적용할 수 없으면 빌드가 중단됩니다. RBD 하위 패키지에만 `.ablestack.1`을 붙이고, 해당 SRPM과 같은 버전의 `libvirt-libs` 및 `libvirt-daemon-driver-storage-core` 의존성을 유지합니다.

이미 받은 SRPM과 빌드 의존성이 있는 경우 `./scripts/build_custom_rpm.sh /path/to/libvirt.src.rpm`으로 그 소스를 바로 빌드할 수 있습니다. `--prepare`를 추가하면 spec과 패치만 준비합니다.
