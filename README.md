# DevOps Assignment: Bedrock Budget Guard

Welcome! In this exercise you will build a small tool that manages daily
spend budgets for Amazon Bedrock usage. Everything runs locally: this repo ships a
mock AWS (the [ministack](https://ministack.org) emulator) plus a
simulator that writes realistic Bedrock invocation logs into it. You
need Docker and nothing else. No AWS account is used at any point.

## Start the environment

```bash
docker compose up -d --build
```

This starts:

| Service | What it does |
|---|---|
| `ministack` | AWS emulator on `http://localhost:4566` (CloudWatch Logs, IAM, STS, and more) |
| `seed` | One-shot bootstrap: creates the log group and IAM roles below, then exits |
| `generator` | Continuously writes Bedrock invocation-log records (first records appear after about 2 minutes) |

Credentials are fake and pre-set in `.env` (`test`/`test`, region
`eu-west-1`, account `000000000000`). From your host, point any AWS SDK
or the AWS CLI at `--endpoint-url http://localhost:4566`. From a
container on the compose network, use `http://ministack:4566`.

Quick look at the data:

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=eu-west-1 \
aws logs filter-log-events \
  --log-group-name /aws/bedrock/modelinvocations \
  --limit 3 --endpoint-url http://localhost:4566
```

## What the environment contains

**Log group `/aws/bedrock/modelinvocations`**: each event is one JSON
record in the shape of real Bedrock model invocation logs:

```json
{
  "timestamp": "2026-07-13T09:15:04Z",
  "region": "eu-west-1",
  "modelId": "eu.anthropic.claude-haiku-4-5-20251001-v1:0",
  "identity": { "arn": "arn:aws:sts::000000000000:assumed-role/proj-alpha-app/session-1" },
  "input":  { "inputTokenCount": 1834, "cacheReadInputTokenCount": 900, "cacheWriteInputTokenCount": 0 },
  "output": { "outputTokenCount": 412 }
}
```

**IAM roles** (workloads invoke Bedrock as these roles; the role name is
inside `identity.arn`):

| Role | Tags |
|---|---|
| `proj-alpha-app` | `project=alpha`, `platform=k8s` |
| `proj-alpha-batch` | `project=alpha`, `platform=k8s` |
| `proj-beta-app` | `project=beta`, `platform=k8s` |
| `ai-developers` | `project=shared`, `platform=local` |

Role tags are the source of truth for role-to-project mapping.

## Your task

Build a tool that enforces **daily (UTC day) spend budgets, per
project**:

1. **Track**: continuously compute each project's spend so far today
   from the invocation logs.
2. **Alert**: when a project's spend crosses configurable thresholds
   of its budget (for example 80% and 100%), emit an alert. The
   channel is your choice (stdout, a webhook receiver you add to the
   compose, a file), but a reviewer must be able to see it working.
3. **Enforce**: when a project's budget is fully spent, stop that
   project's Bedrock usage. Enforcement must be idempotent (safe to
   re-run) and must be lifted once it is no longer warranted; you
   decide and document the reset semantics (for example at midnight
   UTC).

The traffic is scripted so that at least one budget is crossed within
roughly the first 2 minutes of a fresh `docker compose up`. Restarting
the generator restarts its clock.

### Constraints

- Any language.
- The tool must be containerized and runnable as part of new compose
  file.
- Reading the logs: the emulator accepts Logs Insights queries
  (`StartQuery`/`GetQueryResults`), but in the pinned version its
  `stats ... by` aggregations return zero rows even though the query
  reports `Complete`. Insights is therefore not usable for this task.
  Use `FilterLogEvents` (or `GetLogEvents`) instead; this is the
  recommended path and costs you nothing in evaluation.

### What we evaluate

- **Correctness**: cost math (including cache read/write tokens),
  UTC day-boundary behavior, and enforcement that is applied and
  lifted cleanly.
- **Flexibility**: how easily budgets, thresholds, and behavior can be
  changed without touching code.
- **Complexity**: a simple solution that fits the problem beats a
  clever one that does not. We read your code for structure, naming,
  error handling, and logging.
- **Understanding**: in the review conversation you will walk us
  through your solution and defend every decision and its trade-offs.
  A short DESIGN.md helps you do that.

## Troubleshooting

- `docker compose logs generator` shows a heartbeat line every minute
  with cumulative event counts; if `written_total` grows, data is
  flowing.
- `docker compose down -v && docker compose up -d --build` resets
  everything (the emulator keeps no state across restarts).
