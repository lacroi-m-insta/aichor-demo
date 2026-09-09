# lite

One tiny image for the jax, jobset, pytorch and xgboost operators.

None of those operators need their framework present to exercise scheduling —
they set env vars, run the container's command and expect exit 0 — so this
image installs nothing. `python:3.11-slim` plus a single `COPY` layer, which
means the build finishes in seconds.

`main.py` prints the topology the operator injected into the pod, emits a few
structured log lines and exits 0:

```
host=exp-abc-worker-0
MASTER_ADDR=exp-abc-master-0
WORLD_SIZE=2
RANK=1
2026-09-09T10:30:48 INFO role=worker-1 host=exp-abc-worker-0 job=0 status=running ...
worker-1 on exp-abc-worker-0 emitted 100 lines
done
```

The env vars it looks for cover all four operators (`RANK`/`WORLD_SIZE` for
pytorch and xgboost, `JAXOPERATOR_*` for jax, `JOB_GLOBAL_INDEX` for jobset),
printing whichever are set. That is what makes a `count` change visible in the
logs: the pod count and each pod's index.

Duration is the first CLI arg, else `LOG_DURATION_SECONDS`, else 5 seconds.

Used by [`aichor_manifests/count-scenarios/`](../aichor_manifests/count-scenarios).
For kuberay see [`ray-lite/`](../ray-lite).
