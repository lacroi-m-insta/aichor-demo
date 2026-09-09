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
| where `count` lives | `types.worker` | `types.worker` | `types.Workers[0]` | `types.worker` | `types.worker` |
| default when absent | 1 | 1 | **0** | 1 | 1 |

`count: -1` is rejected in two independent places, so those five manifests are
expected to fail before anything is scheduled:

- the SDK model — `count` is `Field(..., ge=0)`, so citadel's cloning step
  rejects the manifest and the experiment dies at the `clone` step with
  `manifest failed validation`. This is the one that actually fires;
- varys `ResourcePoolChecker` — `"<scope>.count: must be >= 0"`, a second line
  of defence that a manifest never reaches.

The other fifteen validate cleanly against the SDK models in
[`aichor_sdk/models/`](https://github.com/instadeepai/aichor-product/tree/main/components/aichor_sdk/src/aichor_sdk/models)
(`AIchorManifest`, `VERSION` 0.2.3) — which is what the platform runs, see Notes.

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
- Manifests are `apiVersion: 0.2.2`, matching the rest of the repo, but
  **`apiVersion` is not a version dispatch**. The SDK keeps one model set and
  `apiVersion` is merely a `Literal` listing the accepted strings, so whatever
  the deployed SDK ships validates every manifest regardless of what it
  declares. Declaring 0.2.2 does *not* get 0.2.2 semantics: 0.2.2 wanted
  `types.Master`/`types.Worker` for pytorch and xgboost, 0.2.3 replaced both
  with a single lowercase `worker`, and 0.2.3 is what validates today. The
  per-version files under `web/public/schema/<v>/` are historical snapshots,
  useful for the editor's `$schema` hint but not what the platform enforces.
- Any commit message starting with `exp` + a non-alphanumeric also triggers an
  experiment (the legacy prefix, still live) — worth knowing when writing
  ordinary commit messages in this repo.
- `vertexai` is left out: it only exists from 0.2.3, is GCP-specific, and uses
  `workerPoolSpecs` rather than a `count`. `tf` and `batchjob` are 0.2.2-only
  and gone in 0.2.3.
