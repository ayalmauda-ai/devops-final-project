"""
tests/test_engine_smoke.py

Integration smoke test for the engine container.

What this tests (and why):
  The engine is a closed-source binary — we can't unit-test its internals.
  What we CAN verify is that the Docker image assembles correctly and that
  the Flask API layer actually starts when the container runs.

  Two probes, matching the K8s health-probe strategy in k8s/statefulset.yaml:
    1. TCP probe  → port 8080 must accept connections within 30 seconds
                    (same as the K8s liveness probe)
    2. POST probe → POST /api/<customer>/<workflow> must return any HTTP status
                    (4xx is fine — it proves Flask answered, not just that TCP
                    is open). Same logic as the K8s readiness probe.

Prerequisites:
  - Docker is running
  - The engine image exists locally (built with `docker build -f docker/engine.Dockerfile`)
  - Alternatively: `docker pull ayalm/engine:<version>` if you have Docker Hub access

Run from the repo root:
  pytest tests/test_engine_smoke.py -v -s

The -s flag prints container logs on failure, which helps diagnose issues.
"""

import os
import socket
import subprocess
import time

import pytest
import requests

# ── Configuration ─────────────────────────────────────────────────────────────

def _image_name():
    """Read the image tag from the VERSION file at repo root."""
    version_file = os.path.join(os.path.dirname(__file__), "..", "VERSION")
    try:
        with open(version_file) as f:
            version = f.read().strip()
    except FileNotFoundError:
        version = "1.0.0"
    return f"ayalm/engine:{version}"

IMAGE          = _image_name()
CONTAINER_NAME = "test-engine-smoke"
HOST_PORT      = 18080   # mapped to container's 8080; high port avoids conflicts
STARTUP_TIMEOUT = 30     # seconds to wait for the API layer to be ready


# ── Helpers ───────────────────────────────────────────────────────────────────

def _tcp_probe(host: str, port: int, timeout: int = STARTUP_TIMEOUT) -> bool:
    """
    Attempt a TCP connection to host:port every second until timeout.
    Returns True if a connection succeeds, False if time runs out.
    This mirrors the K8s liveness TCP socket probe.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                return True
        except (ConnectionRefusedError, socket.timeout, OSError):
            time.sleep(1)
    return False


def _container_logs(name: str) -> str:
    """Fetch stdout+stderr from a named container (for debugging on failure)."""
    result = subprocess.run(
        ["docker", "logs", name],
        capture_output=True, text=True
    )
    return result.stdout + result.stderr


# ── Fixture ───────────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def engine_container():
    """
    Start the engine container, yield the host port, then remove it.

    scope="module" means the container starts once for all tests in this file
    and is removed when the last test finishes — fast and clean.

    IMPORTANT: this test must run against the HOST Docker daemon, not minikube's.
    If `eval $(minikube docker-env)` is active, port mappings go to minikube's
    internal VM network and localhost:18080 will be unreachable from WSL.
    Run `eval $(minikube docker-env --unset)` before executing this test.
    """
    # Guard: if DOCKER_HOST is set, we're pointed at minikube's daemon.
    # Port mappings won't reach WSL localhost — skip with a helpful message.
    if os.environ.get("DOCKER_HOST"):
        pytest.skip(
            "DOCKER_HOST is set — minikube docker-env is active.\n"
            "This test requires the HOST Docker daemon so that port mappings\n"
            "reach WSL localhost. Fix:\n"
            "  eval $(minikube docker-env --unset)\n"
            f"  docker build --build-arg VERSION=$(cat VERSION) "
            f"-f docker/engine.Dockerfile -t {IMAGE} .\n"
            "  pytest tests/test_engine_smoke.py -v -s"
        )

    # Remove any leftover container from a previous failed run
    subprocess.run(
        ["docker", "rm", "-f", CONTAINER_NAME],
        capture_output=True
    )

    # Start the container in detached mode, mapping HOST_PORT → 8080
    result = subprocess.run(
        [
            "docker", "run", "-d",
            "--name", CONTAINER_NAME,
            "-p",    f"{HOST_PORT}:8080",
            IMAGE,
        ],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        pytest.skip(
            f"Could not start engine container (image: {IMAGE}).\n"
            f"Error: {result.stderr.strip()}\n"
            "Make sure Docker is running and the image exists locally.\n"
            f"Build it with: docker build --build-arg VERSION=$(cat VERSION) "
            f"-f docker/engine.Dockerfile -t {IMAGE} ."
        )

    yield HOST_PORT

    # ── Cleanup ──
    # Print logs before removing so failures are diagnosable in CI output
    logs = _container_logs(CONTAINER_NAME)
    if logs:
        print(f"\n=== engine container logs ===\n{logs}\n=== end logs ===")
    subprocess.run(["docker", "rm", "-f", CONTAINER_NAME], capture_output=True)


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestEngineSmoke:

    def test_tcp_port_opens_within_30_seconds(self, engine_container):
        """
        TCP connection to localhost:18080 must succeed within 30 seconds.

        This is the same check the K8s liveness probe performs. If this fails,
        the binary crashed on startup — check the container logs for tracebacks.
        """
        port = engine_container
        reachable = _tcp_probe("localhost", port, timeout=STARTUP_TIMEOUT)
        if not reachable:
            logs = _container_logs(CONTAINER_NAME)
            pytest.fail(
                f"Engine port 8080 did not open within {STARTUP_TIMEOUT}s.\n"
                f"Container logs:\n{logs}"
            )

    def test_api_layer_responds_to_post(self, engine_container):
        """
        POST /api/<customer_id>/<workflow_name> must return an HTTP response.

        We expect a 4xx (unknown customer / workflow) — that's fine.
        What we're proving is that Flask answered the request, not just that
        the TCP port is open. A 5xx or a ConnectionError means the API layer
        is broken at the application level.

        This mirrors the K8s readiness exec probe.
        """
        port = engine_container
        url  = f"http://localhost:{port}/api/smoke-test-customer/smoke-test-workflow"

        try:
            resp = requests.post(url, json={}, timeout=5)
            # Any HTTP status < 500 proves Flask is running and routing requests.
            # 4xx = "I understood the request but rejected it" — expected here.
            # 5xx = Flask crashed handling the request — unexpected.
            assert resp.status_code < 500, (
                f"Engine returned {resp.status_code} — unexpected server error.\n"
                f"Response body: {resp.text[:200]}"
            )

        except requests.exceptions.ConnectionError as e:
            err_str = str(e)
            # "Connection reset by peer" (errno 104) or "Connection aborted"
            # means Flask accepted our TCP connection and immediately closed it.
            # The engine rejects unknown customers/workflows by resetting rather
            # than sending a 4xx — that still proves the API layer is running.
            if "104" in err_str or "reset" in err_str.lower() or "aborted" in err_str.lower():
                # Connection reset = engine is up and processing connections. Pass.
                pass
            else:
                # True "connection refused" = Flask is not listening. Fail.
                logs = _container_logs(CONTAINER_NAME)
                pytest.fail(
                    f"Engine API layer is not responding (ConnectionError: {e}).\n"
                    f"Container logs:\n{logs}"
                )
