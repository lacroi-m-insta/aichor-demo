# `count` scenarios

Five operators x four `count` values, one manifest each, so every combination
can be fired at AIchor and compared.

The workloads are deliberately trivial — they print their topology and exit —
because what is under test is how the platform reacts to `count`, not what runs
inside the pod. Images: [`lite/`](../../lite) for jax/jobset/pytorch/xgboost
(no pip install, `python:3.11-slim`) and [`ray-lite/`](../../ray-lite) for
kuberay (no pip install, Ray already in the base image).

## Matrix

| | jax | jobset | kuberay | pytorch | xgboost |
| --- | --- | --- | --- | --- | --- |
| where `count` lives | `types.worker` | `types.worker` | `types.Workers[0]` | `types.Worker` | `types.Worker` |
| default when absent | 1 | 1 | **0** | 1 | 1 |

`count: -1` is rejected in two independent places, so those five manifests are
expected to fail before anything is scheduled:

- the JSON schema — `count` has `minimum: 0`;
- varys `ResourcePoolChecker` — `"<scope>.count: must be >= 0"`.

The other fifteen validate cleanly (checked against the published 0.2.2 schema).

## Expected results

| scenario | jax / jobset / pytorch / xgboost | kuberay |
| --- | --- | --- |
| `count: -1` | rejected at validation | rejected at validation |
| `count: 0` | 0 worker pods | head only |
| `count: 1` | 1 worker pod | head + 1 worker |
| absent | defaults to 1 -> 1 worker pod | defaults to 0 -> head only |

pytorch and xgboost also carry a `Master` at `count: 1`, so the worker count is
the only thing that changes between their four manifests.

## Running them

```sh
scripts/trigger-count-scenarios.sh --dry-run          # show the 20 commits
scripts/trigger-count-scenarios.sh                    # all 20, with a prompt
scripts/trigger-count-scenarios.sh --operator kuberay # just one operator
```

The script makes one empty commit per scenario and pushes each on its own,
because AIchor reads only the **head commit** of a push — a single push
carrying 20 commits would trigger exactly one experiment. See
[`scripts/trigger-count-scenarios.sh`](../../scripts/trigger-count-scenarios.sh).

To trigger one by hand:

```sh
git commit --allow-empty -m "aichor(count-scenarios/kuberay/count-0.yaml): kuberay, count: 0"
git push
```

## Notes

- Paths in the commit message are relative to `aichor_manifests/`, which is why
  these live here rather than next to the demo they belong to.
- Manifests are `apiVersion: 0.2.2`, matching the rest of the repo. In 0.2.3
  pytorch and xgboost rename `Master`/`Worker` to a single lowercase `worker`,
  so these would need reshaping to move up.
- Any commit message starting with `exp` + a non-alphanumeric also triggers an
  experiment (the legacy prefix, still live) — worth knowing when writing
  ordinary commit messages in this repo.
- `vertexai` is left out: it only exists from 0.2.3, is GCP-specific, and uses
  `workerPoolSpecs` rather than a `count`. `tf` and `batchjob` are 0.2.2-only
  and gone in 0.2.3.
