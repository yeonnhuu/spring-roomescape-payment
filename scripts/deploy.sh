#!/bin/bash
set -euo pipefail

# ================== 설정 ===================
BRANCH="step2"
PROJECT_DIR="spring-roomescape-payment"
LOG_DIR="./logs"
LOG_PATH="$LOG_DIR/deploy.log"
SWAP_FILE="/swapfile"
SWAP_SIZE_MB=1024

# ================== 출력 함수 ===================
print_step()    { echo -e "\033[1;34m▶ $1\033[0m"; }
print_success() { echo -e "\033[1;32m✅ $1\033[0m"; }
print_error()   { echo -e "\033[1;31m❌ $1\033[0m"; }
print_info()    { echo -e "\033[1;36mℹ️ $1\033[0m"; }

# ================== 에러 핸들링 ===================
trap 'print_error "스크립트 실행 중 에러 발생 (line $LINENO)."' ERR

# ================== 메인 ===================
main() {
    print_step "배포 시작: $(date)"

    ensure_swap
    cd_project
    kill_existing_jar_process "빌드 전"
    update_branch
    build_project
    kill_existing_jar_process "JAR 실행 전"
    start_jar
    tail_logs_if_requested

    print_success "배포 완료: $(date)"
}

ensure_swap() {
    print_step "스왑 파일 확인 중..."
    if [ "$(swapon --show | wc -l)" -eq 0 ]; then
        print_info "스왑 파일 없음 → ${SWAP_SIZE_MB}MB 스왑 생성"
        sudo fallocate -l "${SWAP_SIZE_MB}M" "$SWAP_FILE"
        sudo chmod 600 "$SWAP_FILE"
        sudo mkswap "$SWAP_FILE"
        sudo swapon "$SWAP_FILE"
        print_success "스왑 파일 활성화 완료"
    else
        print_info "스왑 파일 이미 활성화됨"
    fi
}

cd_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "디렉토리 없음: $PROJECT_DIR"
        exit 1
    fi
    cd "$PROJECT_DIR"
}

update_branch() {
    print_step "Git 브랜치 업데이트: $BRANCH"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
}

build_project() {
    print_step "Gradle 빌드 시작"
    ./gradlew clean bootJar --no-daemon -Dorg.gradle.jvmargs="-Xmx512m -XX:MaxMetaspaceSize=256m"
    print_success "빌드 완료"

    JAR_PATH=$(find build/libs -type f -name "*.jar" | head -n 1)
    if [ -z "$JAR_PATH" ]; then
        print_error "JAR 파일 생성 실패: build/libs/*.jar"
        exit 1
    fi
    print_info "→ JAR 파일 위치: $JAR_PATH"
}

kill_existing_jar_process() {
    local phase="$1"
    print_step "[$phase] 실행 중인 JAR 프로세스 종료 시도..."
    PID=$(pgrep -f "java.*\.jar" || true)

    if [ -n "$PID" ]; then
        print_info "→ 종료 대상 PID: $PID"
        kill "$PID"
        sleep 1
    else
        print_info "→ 종료할 프로세스 없음"
    fi
}

start_jar() {
    mkdir -p "$LOG_DIR"

    print_step "JAR 실행 중..."
    nohup java -jar "$JAR_PATH" > "$LOG_PATH" 2>&1 &
    sleep 1

    NEW_PID=$(pgrep -f "java.*$JAR_PATH" || true)
    if [ -n "$NEW_PID" ]; then
        print_success "JAR 실행 성공: PID=$NEW_PID"
        print_info "로그 파일: $LOG_PATH"
    else
        print_error "JAR 실행 실패"
        exit 1
    fi
}

tail_logs_if_requested() {
    if [[ "${TAIL_LOG:-true}" == "true" ]]; then
        print_info "실시간 로그 출력 중 (Ctrl+C로 종료)..."
        tail -f "$LOG_PATH"
    fi
}

# ================== 실행 ===================
main
