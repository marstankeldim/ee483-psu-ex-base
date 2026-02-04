#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ee483-hw1}"
CONTAINER_NAME="${CONTAINER_NAME:-ee483-hw1-run}"

usage() {
  cat <<'EOF'
Usage: ./run_hw1.sh <command>

Commands:
  build   Build the Docker image
  run     Start an interactive container shell
  launch  Launch HW1 ROS node in headless mode
  test    Run topic checks in a running container
  all     Build, start detached container, launch node, run tests
  stop    Stop and remove the named container
EOF
}

container_id() {
  docker ps -q -f "name=^/${CONTAINER_NAME}$"
}

require_container() {
  local cid
  cid="$(container_id)"
  if [[ -z "${cid}" ]]; then
    echo "No running container named ${CONTAINER_NAME}."
    echo "Start one with: ./run_hw1.sh all"
    exit 1
  fi
  echo "${cid}"
}

cmd="${1:-}"
case "${cmd}" in
  build)
    docker build -t "${IMAGE_NAME}" .
    ;;
  run)
    docker run --rm -it --name "${CONTAINER_NAME}" "${IMAGE_NAME}" bash
    ;;
  launch)
    cid="$(require_container)"
    docker exec -it "${cid}" bash -lc \
      "source /environment.sh && roslaunch intern_pkg ex1_launch.launch use_turtlesim:=false use_rqt:=false"
    ;;
  test)
    cid="$(require_container)"
    docker exec -it "${cid}" bash -lc \
      "source /environment.sh && rostopic list | grep cmd_vel && rostopic type /sim/turtle1/cmd_vel && rostopic echo -n 6 /sim/turtle1/cmd_vel"
    ;;
  all)
    docker build -t "${IMAGE_NAME}" .
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker run -d --name "${CONTAINER_NAME}" "${IMAGE_NAME}" bash -lc "sleep infinity" >/dev/null
    echo "Container started: ${CONTAINER_NAME}"
    echo "Starting roslaunch in background..."
    docker exec -d "${CONTAINER_NAME}" bash -lc \
      "source /environment.sh && roslaunch intern_pkg ex1_launch.launch use_turtlesim:=false use_rqt:=false"
    sleep 3
    echo "Running tests..."
    docker exec -it "${CONTAINER_NAME}" bash -lc \
      "source /environment.sh && rostopic list | grep cmd_vel && rostopic type /sim/turtle1/cmd_vel && rostopic echo -n 6 /sim/turtle1/cmd_vel"
    echo "Done. Stop with: ./run_hw1.sh stop"
    ;;
  stop)
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    echo "Stopped ${CONTAINER_NAME}."
    ;;
  *)
    usage
    exit 1
    ;;
esac
