#!/usr/bin/env bash
# ==============================================================================
# Fiverr Club Ecosystem — Unified Startup & Orchestration Script (start.sh)
# Organization: https://github.com/fiverr-club
# ==============================================================================
# Usage:
#   ./start.sh            Auto-detect & start (Docker Compose if available, else local processes)
#   ./start.sh docker     Start full stack via Docker Compose (Postgres, Redis, Kafka, 9 Services, Web)
#   ./start.sh local      Build & run all 9 Spring Boot microservices + Next.js Web locally on host
#   ./start.sh web        Start Next.js Marketplace Web App only (http://localhost:3000)
#   ./start.sh k8s        Deploy full ecosystem to Kubernetes via Kustomize
#   ./start.sh helm       Deploy full ecosystem to Kubernetes via Helm v3 chart
#   ./start.sh test       Run unit tests across all 9 microservices + verify Next.js build
#   ./start.sh status     Check health & port status of all Fiverr Club services
#   ./start.sh stop       Stop all running local processes and Docker Compose containers
# ==============================================================================

set -euo pipefail

# Resolve workspace root whether invoked from /fiverr-club or /fiverr-club/fiverr-k8s-infra
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "fiverr-k8s-infra" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$SCRIPT_DIR"
fi

K8S_INFRA_DIR="$ROOT_DIR/fiverr-k8s-infra"
LOG_DIR="$ROOT_DIR/.logs"
PID_DIR="$ROOT_DIR/.pids"

# Configure Java 21 if installed via Homebrew on macOS
if [[ -d "/opt/homebrew/opt/openjdk@21" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

SERVICES=(
  "fiverr-api-gateway:8080"
  "fiverr-auth-service:8081"
  "fiverr-user-service:8082"
  "fiverr-gig-service:8083"
  "fiverr-order-service:8084"
  "fiverr-payment-service:8085"
  "fiverr-messaging-service:8086"
  "fiverr-review-service:8087"
  "fiverr-notification-service:8088"
)

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

banner() {
  echo -e "${GREEN}======================================================================${NC}"
  echo -e "${GREEN}  Fiverr Club Ecosystem — Microservices & Kubernetes Launcher${NC}"
  echo -e "${BLUE}  GitHub Org : https://github.com/fiverr-club${NC}"
  echo -e "${BLUE}  Workspace  : ${ROOT_DIR}${NC}"
  echo -e "${GREEN}======================================================================${NC}"
}

print_endpoints() {
  echo ""
  echo -e "${GREEN}Service Endpoints:${NC}"
  echo "  - Web Marketplace (Next.js) : http://localhost:3000"
  echo "  - API Gateway               : http://localhost:8080"
  echo "  - Auth / IAM Service        : http://localhost:8081/actuator/health"
  echo "  - User Profile Service      : http://localhost:8082/actuator/health"
  echo "  - Gig Catalog Service       : http://localhost:8083/actuator/health"
  echo "  - Order & Escrow Service    : http://localhost:8084/actuator/health"
  echo "  - Payment & Wallet Service  : http://localhost:8085/actuator/health"
  echo "  - Messaging & Chat Service  : http://localhost:8086/actuator/health"
  echo "  - Review & Rating Service   : http://localhost:8087/actuator/health"
  echo "  - Notification Service      : http://localhost:8088/actuator/health"
  echo ""
}

start_docker() {
  banner
  echo -e "${BLUE}[Docker Compose] Starting PostgreSQL, Redis, Kafka, 9 Microservices, and Next.js Web...${NC}"
  cd "$K8S_INFRA_DIR"
  docker compose up --build -d
  print_endpoints
  echo -e "${GREEN}All containers started! Run './start.sh status' or 'docker compose -f fiverr-k8s-infra/docker-compose.yml logs -f' to monitor.${NC}"
}

start_web_only() {
  banner
  mkdir -p "$LOG_DIR" "$PID_DIR"
  echo -e "${BLUE}[Web] Starting fiverr-web (Next.js 15) on http://localhost:3000...${NC}"
  cd "$ROOT_DIR/fiverr-web"
  if [[ ! -d "node_modules" ]]; then
    npm install
  fi
  nohup npm run dev > "$LOG_DIR/fiverr-web.log" 2>&1 &
  echo $! > "$PID_DIR/fiverr-web.pid"
  echo -e "${GREEN}fiverr-web started (PID $(cat "$PID_DIR/fiverr-web.pid")) -> http://localhost:3000${NC}"
  echo -e "Logs: ${LOG_DIR}/fiverr-web.log"
}

start_local() {
  banner
  mkdir -p "$LOG_DIR" "$PID_DIR"

  # If Docker is running, spin up Postgres, Redis, and Kafka containers for the local services
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo -e "${BLUE}[Infra] Starting PostgreSQL, Redis, and Kafka via Docker Compose...${NC}"
    (cd "$K8S_INFRA_DIR" && docker compose up -d fiverr-postgres fiverr-redis fiverr-kafka)
  else
    echo -e "${YELLOW}[Infra] Docker daemon not running; ensure local PostgreSQL (:5432), Redis (:6379), and Kafka (:9092) are available.${NC}"
  fi

  for entry in "${SERVICES[@]}"; do
    svc="${entry%%:*}"
    port="${entry##*:}"
    echo -e "${BLUE}[Build & Run] Starting ${svc} on port ${port}...${NC}"
    (
      cd "$ROOT_DIR/$svc"
      mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=${port}" > "$LOG_DIR/${svc}.log" 2>&1 &
      echo $! > "$PID_DIR/${svc}.pid"
    )
    echo -e "  -> ${GREEN}${svc}${NC} launched (PID $(cat "$PID_DIR/${svc}.pid"), log: .logs/${svc}.log)"
  done

  echo -e "${BLUE}[Web] Starting fiverr-web on port 3000...${NC}"
  (
    cd "$ROOT_DIR/fiverr-web"
    [[ ! -d "node_modules" ]] && npm install
    nohup npm run dev > "$LOG_DIR/fiverr-web.log" 2>&1 &
    echo $! > "$PID_DIR/fiverr-web.pid"
  )
  echo -e "  -> ${GREEN}fiverr-web${NC} launched (PID $(cat "$PID_DIR/fiverr-web.pid"), log: .logs/fiverr-web.log)"

  print_endpoints
}

start_k8s() {
  banner
  echo -e "${BLUE}[Kubernetes] Deploying Fiverr Club ecosystem via Kustomize...${NC}"
  bash "$K8S_INFRA_DIR/scripts/deploy-k8s.sh" --mode kustomize
}

start_helm() {
  banner
  echo -e "${BLUE}[Helm v3] Deploying Fiverr Club ecosystem via Helm chart...${NC}"
  bash "$K8S_INFRA_DIR/scripts/deploy-k8s.sh" --mode helm
}

run_tests() {
  banner
  for entry in "${SERVICES[@]}"; do
    svc="${entry%%:*}"
    echo -e "${BLUE}[Test] Running unit tests for ${svc}...${NC}"
    (cd "$ROOT_DIR/$svc" && mvn test)
  done
  echo -e "${BLUE}[Build] Verifying Next.js production build for fiverr-web...${NC}"
  (cd "$ROOT_DIR/fiverr-web" && npm run build)
  echo -e "${GREEN}All 9 microservice test suites and Next.js build succeeded!${NC}"
}

check_status() {
  banner
  echo -e "${BLUE}Checking local ports:${NC}"
  local all_ports=("fiverr-web:3000" "${SERVICES[@]}" "postgres:5432" "redis:6379" "kafka:9092")
  for item in "${all_ports[@]}"; do
    name="${item%%:*}"
    port="${item##*:}"
    if lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
      echo -e "  [UP]   ${GREEN}${name}${NC} (port ${port})"
    else
      echo -e "  [DOWN] ${YELLOW}${name}${NC} (port ${port})"
    fi
  done
}

stop_all() {
  banner
  if [[ -d "$PID_DIR" ]]; then
    for pid_file in "$PID_DIR"/*.pid; do
      [[ -e "$pid_file" ]] || continue
      svc_name="$(basename "$pid_file" .pid)"
      pid="$(cat "$pid_file")"
      if kill -0 "$pid" >/dev/null 2>&1; then
        echo -e "${YELLOW}Stopping ${svc_name} (PID ${pid})...${NC}"
        kill "$pid" >/dev/null 2>&1 || true
      fi
      rm -f "$pid_file"
    done
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping Docker Compose services...${NC}"
    (cd "$K8S_INFRA_DIR" && docker compose down)
  fi

  echo -e "${GREEN}All Fiverr Club services stopped.${NC}"
}

MODE="${1:-auto}"

case "$MODE" in
  auto)
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      start_docker
    else
      start_local
    fi
    ;;
  docker|compose)
    start_docker
    ;;
  local|dev)
    start_local
    ;;
  web)
    start_web_only
    ;;
  k8s|kubernetes)
    start_k8s
    ;;
  helm)
    start_helm
    ;;
  test|verify)
    run_tests
    ;;
  status|ps)
    check_status
    ;;
  stop|down)
    stop_all
    ;;
  *)
    echo "Usage: $0 {auto|docker|local|web|k8s|helm|test|status|stop}"
    exit 1
    ;;
esac
