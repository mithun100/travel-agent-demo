# Travel Agent Demo

AI observability demo: a multi-agent travel planner instrumented with OpenTelemetry, DeepEval, and Splunk.

---

## Prerequisites

- Docker + Docker Compose v2 (`docker compose version`)
- A `.env` file with credentials (see Setup below)

---

## Setup

```bash
git clone https://github.com/mithun100/travel-agent-demo.git
cd travel-agent-demo
cp .env.example .env
```

Edit `.env` and fill in your credentials:

| Variable                                                        | Description                                                      |
| --------------------------------------------------------------- | ---------------------------------------------------------------- |
| `LAB_USER_ID`                                                   | Your unique lab ID (e.g. `pod01`) — tags all telemetry in Splunk |
| `AWS_BEDROCK_MODEL_ID` + AWS keys                               | Required for Bedrock backend                                     |
| `NGC_API_KEY` + NIM vars                                        | Required for NVIDIA NIM backend                                  |
| `SPLUNK_ACCESS_TOKEN` + `SPLUNK_REALM`                          | Splunk Observability Cloud                                       |
| `SPLUNK_HEC_TOKEN` + `SPLUNK_HEC_ENDPOINT` + `SPLUNK_HEC_INDEX` | Splunk Platform (logs)                                           |
| `DEEPEVAL_LLM_*`                                                | Azure OpenAI used as DeepEval judge LLM                          |
| `LLM_BACKEND`                                                   | `bedrock` \| `nim` \| `azure`                                    |

---

## Start / Stop

```bash
./docker/docker-deploy.sh          # build images and start all services
./docker/docker-deploy.sh down     # stop everything
./docker/docker-deploy.sh logs     # tail all logs
./docker/docker-deploy.sh ps       # show running containers
```

---

## Demo Flow

### Act 1+2 — Baseline (clean requests, good scores)

```bash
./docker/docker-deploy.sh test     # quick smoke test
./scripts/baseline.sh              # send 3 clean requests → Splunk shows good eval scores
```

### Act 3 — Poison Injection (trigger the alert)

```bash
./scripts/poison.sh                # inject negative sentiment into all 5 agents
./scripts/poison.sh light          # inject into 1 agent only (subtle)
```

Wait ~2-3 minutes → Splunk IM alert fires on sentiment score failure.

---

## Switch LLM Backend

```bash
./scripts/set-backend.sh bedrock   # AWS Bedrock (default)
./scripts/set-backend.sh nim       # NVIDIA NIM
./scripts/set-backend.sh azure     # Azure OpenAI
```

---

## Architecture

```
User → Flask App (travel-planner)
         └── LangGraph pipeline
               ├── coordinator
               ├── flight_specialist
               ├── hotel_specialist
               ├── activity_specialist
               └── plan_synthesizer
                     └── OpenTelemetry → otel-collector → Splunk IM / APM / Platform
                                              └── DeepEval (sentiment eval on each agent span)
```

