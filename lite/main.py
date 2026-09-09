"""Tiny workload for the jax, jobset, pytorch and xgboost operators.

Prints the topology the operator injected into this pod, emits a few log lines
and exits 0. Nothing framework-specific is imported, so one image serves every
operator and the build stays a single COPY layer.
"""

import os
import random
import socket
import sys
import time

# Env vars the operators inject. Printing them is what makes a `count` change
# visible: they show how many pods exist and which one this is.
TOPOLOGY_ENV = [
    # pytorch, xgboost
    "MASTER_ADDR",
    "MASTER_PORT",
    "WORLD_SIZE",
    "RANK",
    # xgboost
    "WORKER_PORT",
    "WORKER_ADDRS",
    # jax
    "JAXOPERATOR_COORDINATOR_ADDRESS",
    "JAXOPERATOR_NUM_PROCESSES",
    "JAXOPERATOR_PROCESS_ID",
    # jobset
    "JOB_GLOBAL_INDEX",
    "JOB_COMPLETION_INDEX",
    "JOBSET_NAME",
    # aichor
    "AICHOR_EXPERIMENT_MESSAGE",
]

# Seconds of logs: first CLI arg wins, else env, else 5.
DURATION = float(sys.argv[1] if len(sys.argv) > 1 else os.getenv("LOG_DURATION_SECONDS", "5"))


def print_topology(host: str) -> None:
    print(f"host={host}", flush=True)
    for key in TOPOLOGY_ENV:
        value = os.environ.get(key)
        if value is not None:
            print(f"{key}={value}", flush=True)


def emit_logs(role: str, host: str, duration: float) -> int:
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
    return i


if __name__ == "__main__":
    host = socket.gethostname()
    print_topology(host)

    # Whatever the operator calls this pod, the rank-ish vars agree on the index.
    role = (
        os.environ.get("RANK")
        or os.environ.get("JAXOPERATOR_PROCESS_ID")
        or os.environ.get("JOB_GLOBAL_INDEX")
        or "0"
    )
    lines = emit_logs(f"worker-{role}", host, DURATION)
    print(f"worker-{role} on {host} emitted {lines} lines", flush=True)
    print("done", flush=True)
