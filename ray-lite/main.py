"""Minimal KubeRay demo: the head and every worker emit structured log lines.

The head connects to the cluster, waits for the workers to register, then runs
one task pinned to each worker node so that every pod produces its own logs.
"""

import os
import random
import socket
import sys
import time

import ray
from ray.util.scheduling_strategies import NodeAffinitySchedulingStrategy

# Seconds of logs each node emits: first CLI arg wins, else env, else 5.
DURATION = float(sys.argv[1] if len(sys.argv) > 1 else os.getenv("LOG_DURATION_SECONDS", "5"))
NODE_WAIT_TIMEOUT = float(os.getenv("RAY_NODE_WAIT_TIMEOUT", "120"))


def emit_logs(role: str, duration: float) -> str:
    host = socket.gethostname()
    end = time.time() + duration
    i = 0
    while time.time() < end:
        print(
            f"{time.strftime('%Y-%m-%dT%H:%M:%S')} INFO role={role} host={host} "
            f"job={i % 20} status=running loss=0.{random.randrange(10000):04d} "
            f"acc=0.{5000 + random.randrange(5000)} iter={i} "
            f"msg=training_step_completed",
            flush=True,
        )
        i += 1
        time.sleep(0.05)
    return f"{role} on {host} emitted {i} lines"


@ray.remote(num_cpus=0.1)
def emit_logs_remote(role: str, duration: float) -> str:
    return emit_logs(role, duration)


def alive_nodes():
    return [n for n in ray.nodes() if n.get("Alive")]


def wait_for_workers(head_node_id: str, timeout: float):
    """Wait for at least one non-head node, so the worker gets a task too."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        workers = [n for n in alive_nodes() if n["NodeID"] != head_node_id]
        if workers:
            return workers
        print("waiting for worker nodes to join the cluster...", flush=True)
        time.sleep(2)
    print(f"no worker joined within {timeout}s, running on the head only", flush=True)
    return []


if __name__ == "__main__":
    ray.init(address=os.environ.get("RAY_ADDRESS", "auto"))

    head_node_id = ray.get_runtime_context().get_node_id()
    workers = wait_for_workers(head_node_id, NODE_WAIT_TIMEOUT)
    print(f"cluster ready: 1 head + {len(workers)} worker(s)", flush=True)

    # One task per worker node, pinned so each pod logs on its own.
    tasks = [
        emit_logs_remote.options(
            scheduling_strategy=NodeAffinitySchedulingStrategy(
                node_id=node["NodeID"], soft=False
            )
        ).remote(f"worker-{idx}", DURATION)
        for idx, node in enumerate(workers)
    ]

    print(emit_logs("head", DURATION), flush=True)

    # Collect per task so one dead node still reports the others' output.
    failed = 0
    for task in tasks:
        try:
            print(ray.get(task), flush=True)
        except Exception as exc:  # node lost, task killed, ...
            failed += 1
            print(f"worker task failed: {exc}", flush=True)

    if failed:
        print(f"done with {failed} failed worker task(s)", flush=True)
        sys.exit(1)

    print("done", flush=True)
