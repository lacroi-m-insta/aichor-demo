# ray-lite

Minimal KubeRay demo: a head and one worker, each printing structured logs.

It exists as a fast-building alternative to `raytune-pong`, which pulls the
`-gpu` Ray base image and pip-installs torch, Atari ROMs and the rest of a
~90-package lock file. Here the CPU Ray image already contains everything, so
the Dockerfile has **no pip install step** — the build is a single `COPY` layer.

| | raytune-pong | ray-lite |
| --- | --- | --- |
| base image | `rayproject/ray:2.36.1-py39-gpu` | `rayproject/ray:2.36.1-py39-cpu` |
| pip install | ~90 packages incl. torch 2.4.1 | none |
| build steps | pip resolve + install | one `COPY` |

## What it does

`main.py` runs as the driver on the head:

1. connects to the cluster (`RAY_ADDRESS`, default `auto`);
2. waits for the workers to register (`RAY_NODE_WAIT_TIMEOUT`, default 120s —
   if none joins it logs on the head alone rather than failing);
3. launches one task per worker node, pinned with
   `NodeAffinitySchedulingStrategy(soft=False)` so each pod logs on its own;
4. emits its own log lines on the head, then collects each task.

A failed worker task is reported on one line and the run exits 1; the other
tasks' output is still printed.

Both roles emit the same shape of line:

```
2026-09-07T15:35:30 INFO role=worker-0 host=ecc3035b2bf5 job=0 status=running loss=0.4687 acc=0.6100 iter=0 msg=training_step_completed
```

Worker lines reach the head's log stream prefixed by Ray with
`(emit_logs_remote pid=..., ip=...)`, and also appear in each worker pod's logs.

## Configuration

| | default | |
| --- | --- | --- |
| first CLI arg / `LOG_DURATION_SECONDS` | 5 | seconds of logs per node |
| `RAY_NODE_WAIT_TIMEOUT` | 120 | seconds to wait for workers |

`spec.env` is not part of manifest schema 0.2.2, so the duration is passed on
the command line: `command: "python3 -u main.py 5"`.

## Run it

```sh
aichor experiment start -f ray-lite/manifests/manifest.yaml
```

Keep `spec.rayVersion` in sync with the base image tag in the Dockerfile.
