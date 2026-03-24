# os-images

※ Opus 4.6 작성

[Universal Blue](https://universal-blue.org/) 프로젝트의 [Bazzite](https://bazzite.gg/) 이미지를 기반으로 커스터마이징한 [bootc](https://github.com/bootc-dev/bootc) 컨테이너 이미지 빌드 시스템이다.

## 특징

- **Variant 기반 빌드**: desktop(Bazzite), HTPC(Bazzite-Deck) 등 용도별 이미지를 분리하여 관리한다.
- **2-stage Containerfile**: `FROM scratch AS ctx` 패턴으로 빌드 스크립트를 bind mount하여 최종 이미지에 불필요한 레이어를 남기지 않는다.
- **디스크 이미지 생성**: [bootc-image-builder](https://osbuild.org/docs/bootc/)를 통해 QCOW2, RAW, ISO 디스크 이미지를 생성할 수 있다.

## 빌드 요구 사항

- [Podman](https://podman.io/)
- [Just](https://just.systems/) (Universal Blue 이미지에 기본 포함)
- 디스크 이미지 빌드 시 rootful Podman 필요

## 사용법

### OCI 컨테이너 이미지 빌드

```bash
just build [variant=desktop] [tag=latest]
```

로컬에서 빠르게 검증하고 바로 부팅 대상에 반영하려면 다음 명령을 사용할 수 있다.

```bash
# 로컬 빌드 후 containers-storage 기반으로 전환
just bootc-switch-local [variant=desktop] [tag=latest]

# 로컬 빌드 후 즉시 재부팅까지 수행
just bootc-switch-local-apply [variant=desktop] [tag=latest]

# 다시 GHCR 원격 이미지를 추적하도록 복귀
just bootc-switch-remote [variant=desktop] [tag=latest]

# 현재 bootc 상태 확인
just bootc-status
```

이 로컬 테스트 흐름은 이미지 이름을 `ghcr.io/...` 형태로 유지하되, 실제 전환은 `containers-storage` transport를 사용한다. 원격 GHCR 추적으로 돌아가려면 `bootc-switch-remote`를 실행하면 된다.

### 디스크 이미지 빌드

```bash
just build-qcow2 [variant=desktop] [tag=latest]
just build-raw [variant=desktop] [tag=latest]
just build-iso [variant=desktop] [tag=latest]
```

`rebuild-*` 명령은 컨테이너 이미지를 다시 빌드한 뒤 디스크 이미지를 생성한다.

```bash
just rebuild-qcow2 [variant=desktop] [tag=latest]
```

### 가상 머신 실행

```bash
# QEMU (브라우저 VNC 접속)
just run-vm-qcow2 [variant=desktop] [tag=latest]

# systemd-vmspawn
just spawn-vm [rebuild=0] [type=qcow2] [ram=6G]
```

### 코드 검사 및 포매팅

```bash
just check    # pre-merge-commit 훅 실행
just format   # pre-commit 훅 실행
just clean    # 빌드 아티팩트 제거
```

## 이미지 전환

bootc 시스템에서 다음 명령으로 이미지를 전환할 수 있다.

```bash
sudo bootc switch ghcr.io/hnjae/os-images-<variant>:latest
```

`just bootc-switch-remote`는 위 명령을 래핑한 레시피다.

## 이미지 서명 검증

배포된 이미지는 cosign으로 서명되어 있으며, 리포지토리의 `cosign.pub` 키로 검증할 수 있다.

```bash
cosign verify --key cosign.pub ghcr.io/<username>/os-images-<variant>:latest
```

## CI/CD 설정

### OCI 이미지 빌드 (build.yaml)

main 브랜치 push, 매일 10:05 UTC, PR 시 자동 실행된다. 빌드된 이미지는 GHCR에 push되고 cosign으로 서명된다.

### 디스크 이미지 빌드 (build-disk.yaml)

수동 dispatch 또는 `disk_config/` 변경 시 실행된다. 빌드 결과물은 GitHub Actions artifact로 다운로드하거나 S3에 업로드할 수 있다.

S3 업로드를 위해 다음 시크릿을 설정해야 한다:

- `S3_PROVIDER` — [rclone 지원 목록](https://rclone.org/s3/) 참조
- `S3_BUCKET_NAME`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `S3_REGION`
- `S3_ENDPOINT`

### cosign 키 설정

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
gh secret set SIGNING_SECRET < cosign.key
```

비밀번호 없이 키를 생성해야 한다.
