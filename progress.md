# DevOps Final Project — Progress & Handoff Notes

> **Purpose of this file:** Single source of truth for project status. Drop this (plus the roadmap docx) into any new Claude session and the assistant has full context to pick up exactly where you left off.

---

## Project at a glance

- **Student:** Ayal Mauda
- **GitHub:** `ayalmauda-ai`
- **Docker Hub:** `ayalm`
- **Project repo:** `github.com/ayalmauda-ai/devops-final-project`
- **Base project (corrected URL):** `https://github.com/gagishmagi/seyoawe-community`
  - Originally referenced as `yuribernstein/seyoawe-community` in course materials; that path no longer resolves. Use the `gagishmagi` fork.
- **Target stack:** AWS EKS · Terraform · Ansible · Jenkins · Docker Hub · Prometheus + Grafana
- **Roadmap document:** `DevOps_Final_Roadmap.docx` (kept up to date conceptually; some specifics below supersede it where reality differs from the original assumptions)
- **Local working directory:** `~/study/final-project` (in WSL Ubuntu 24.04)

## How to use this file when starting a new chat

Paste this prompt into a fresh Claude conversation:

> "I'm working on my DevOps final project. The full roadmap is in `DevOps_Final_Roadmap.docx` and current status is in `progress.md` (both attached). I'm currently working on **[phase X]** and need help with **[specific thing]**. Please read both files, then continue from where the last session left off."

Then attach both files.

---

## What seyoawe-community actually is (CRITICAL — supersedes the roadmap)

The roadmap was written assuming a pure Python project. The base project is actually a **hybrid Python + closed-source Linux binary**:

- **`seyoawe.linux`** — proprietary ~20 MB ELF binary; the Flask-powered engine runtime. Listens on **port 8080**, exposes only `POST /api/<customer_id>/<workflow_name>`. **No `/health` endpoint exists.**
- **`modules/`** — Python plugins loaded by the engine at runtime (chatbot, email, slack, git, etc.). Source available.
- **`sawectl/sawectl.py`** — Python CLI (22 KB source) for managing workflows. Dependencies: `pyyaml`, `jsonschema`, `requests`.
- **`workflows/`, `configuration/`** — runtime YAML configs.
- **`CHECKLIST.md`** — upstream's own setup guide; useful reference, keep in repo as `UPSTREAM-CHECKLIST.md`.
- **No tests exist anywhere upstream.**
- **License:** dual (Community / Commercial). We're using the Community edition.

### Implications

| Topic | What this means for us |
|---|---|
| Engine source code | We don't have it. We containerize the binary as-is. The CI lints/tests the open-source Python modules, not the binary. |
| K8s health probes | TCP-socket probes on port 8080 (canonical pattern when no /health endpoint exists). Readiness uses a POST probe that checks for any connection (proves the API layer is up, not just TCP). |
| CLI testing | `sawectl.py` is real Python source — 17 unit tests written covering argument parsing, load_yaml, extract_module_and_method, and validate_step. All pass. |
| Engine testing | Integration smoke test: boot container, TCP probe :8080 within 30s, POST probe for connection reset (engine's rejection behavior proves Flask is up). Both pass. |
| Version coupling | One VERSION file, one writer (engine-ci), VERSION changes trigger both pipelines. |

---

## Model strategy (which Claude to use when)

| Phase | Recommended model | Reason |
|-------|-------------------|--------|
| 0 — Prerequisites & accounts | Sonnet 4.6 | Standard installs |
| 1 — Repo structure | Sonnet 4.6 | Mechanical scaffolding |
| 2 — Containerization | Sonnet 4.6 | Standard Dockerfiles |
| 3 — Kubernetes (StatefulSet) | Sonnet 4.6 | StatefulSet trap is real but handled |
| 4 — Engine CI Jenkinsfile | Sonnet 4.6 | Standard pipeline |
| 5 — CLI CI Jenkinsfile | Sonnet 4.6 | Standard pipeline |
| **6 — Version coupling logic** | **Opus 4.7** ✅ DONE | Designed and tested |
| **7 — Terraform AWS EKS** | **Sonnet 4.6** ✅ DONE | Official modules did the heavy lifting |
| **8 — Ansible** | **Sonnet 4.6** ✅ DONE | Standard playbook patterns |
| **9 — CD pipeline sequencing** | **Sonnet 4.6** ✅ DONE | Sequential stages, no rollback needed for course |
| 10 — Observability (bonus) | Sonnet 4.6 | helm install + dashboards |
| 11 — RAG bonus | Opus 4.7 | Architecture territory |
| **Stuck >20 min on anything** | **Opus 4.7** | Deep debug pays off |

> **Important:** Models can't be switched mid-session in Cowork. Start a new session to switch.

---

## Status board

| # | Phase | Status | Last touched | Notes |
|---|-------|--------|--------------|-------|
| 0 | Prerequisites & accounts | ✅ Done | 2026-05-19 | All tools installed, AWS infra (S3 + DynamoDB) ready |
| 1 | Repo structure & base project | ✅ Done | 2026-05-19 | Repo at `ayalmauda-ai/devops-final-project` |
| 2 | Containerization | ✅ Done | 2026-05-19 | engine.Dockerfile, cli.Dockerfile, jenkins.Dockerfile |
| 3 | Kubernetes manifests (StatefulSet) | ✅ Done | 2026-05-19 | StatefulSet + headless service + configmap + ingress. TCP probes (no /health). imagePullPolicy: IfNotPresent for EKS. |
| 4 | CI pipeline for Engine | ✅ Done | 2026-05-20 | jenkins/Jenkinsfile.engine-ci with detect-changes + bump-version |
| 5 | CI pipeline for CLI | ✅ Done | 2026-05-20 | jenkins/Jenkinsfile.cli-ci, pyproject.toml, 17 unit tests |
| **6** | **Version coupling logic** | **✅ Done** | **2026-05-20** | VERSION at root, detect-changes.sh, bump-version.sh. 9/9 scenarios pass. |
| **7** | **Terraform AWS EKS** | **✅ Done** | **2026-05-20** | backend.tf, providers.tf, variables.tf, vpc.tf, eks.tf, outputs.tf, .terraform.lock.hcl committed. `terraform validate` passes. |
| **8** | **Ansible** | **✅ Done** | **2026-05-20** | ansible.cfg, inventory/hosts.ini, playbooks/configure-eks.yml (updates kubeconfig + installs ingress-nginx) |
| **9** | **CD pipeline** | **✅ Done** | **2026-05-20** | jenkins/Jenkinsfile.cd — Terraform → Ansible → kubectl, strictly sequential |
| 10 | Observability bonus | 🟡 Next | — | Prometheus + Grafana via Helm into monitoring/ namespace |
| 11 | AI RAG bonus | ⬜ Not started | — | Optional — tackle after Phase 10 if time allows |

**Status legend:** ⬜ Not started · 🟡 In progress · 🔴 Blocked · ✅ Done

---

## Repo structure (current state)

```
devops-final-project/
├── VERSION                          # 1.0.0 — single source of truth for semver
├── README.md                        # includes version-coupling design section
├── engine/                          # seyoawe.linux binary + run.sh + modules/
├── cli/
│   ├── sawectl/                     # sawectl.py CLI source
│   ├── tests/test_sawectl.py        # 17 unit tests — all pass
│   └── pyproject.toml               # for wheel build in cli-ci
├── docker/
│   ├── engine.Dockerfile
│   ├── cli.Dockerfile
│   └── jenkins.Dockerfile
├── k8s/
│   ├── statefulset.yaml             # imagePullPolicy: IfNotPresent (EKS-ready)
│   ├── service.yaml                 # headless (engine-svc) + ClusterIP (engine-external)
│   ├── configmap.yaml
│   ├── ingress.yaml
│   └── secret.yaml.example
├── terraform/
│   ├── backend.tf                   # S3 state + DynamoDB lock
│   ├── providers.tf                 # AWS ~> 5.0, Kubernetes ~> 2.0
│   ├── variables.tf
│   ├── vpc.tf                       # 2 AZs, single NAT, subnet tags for LB controller
│   ├── eks.tf                       # managed node group, t3.medium x2
│   ├── outputs.tf                   # cluster_name, endpoint, region, CA, OIDC ARN
│   ├── .gitignore
│   └── .terraform.lock.hcl          # pinned provider versions — committed
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.ini          # localhost, ansible_connection=local
│   └── playbooks/configure-eks.yml  # kubeconfig update + ingress-nginx Helm install
├── jenkins/
│   ├── Jenkinsfile.engine-ci        # lint → smoke test → build+push → bump version
│   ├── Jenkinsfile.cli-ci           # tests → build+push → GitHub Release wheel
│   ├── Jenkinsfile.cd               # Terraform → Ansible → kubectl (sequential)
│   └── shared/
│       ├── detect-changes.sh        # decides which pipeline runs
│       └── bump-version.sh          # idempotent semver patch bumper
├── monitoring/                      # Phase 10: Prometheus + Grafana (not started)
└── tests/
    └── test_engine_smoke.py         # 2 integration tests — TCP probe + API probe. Both pass.
```

---

## Phase 6 design at a glance

Three rules: **one source of truth (`VERSION`), one writer (engine-ci on main only), `VERSION` changes trigger both pipelines.**

Failure modes defended in code: infinite loop (via `[skip ci]` + self-detection), double-bump (skip if manual VERSION change in HEAD), CLI orphan (VERSION-triggers-both), race (rebase+retry + `disableConcurrentBuilds`), PR-branch bump (only on main).

---

## Phase 10 hand-off prompt (for the next session)

> "I'm working on my DevOps final project — see `progress.md` and `DevOps_Final_Roadmap.docx`. Phases 0–9 are complete and all tests pass. I'm now starting **Phase 10 (Observability bonus)** — Prometheus + Grafana. The app (seyoawe engine) runs on port 8080, exposes `POST /api/<customer>/<workflow>`. No /health endpoint exists. The cluster is AWS EKS (`devops-final-eks`, us-east-1), ingress-nginx is already installed. I want to: (a) create a `monitoring/` folder with Helm values files for kube-prometheus-stack, (b) expose Grafana via the existing ingress-nginx, (c) add a basic dashboard for HTTP request rate on port 8080. Let's start with `monitoring/values-prometheus.yaml`."

---

## Phase 0 — Tools (live)

- [x] OS: Ubuntu 24.04.1 LTS
- [x] git 2.43.0
- [x] python3 3.12.3
- [x] java openjdk 17.0.18
- [x] ansible-core 2.16.3
- [x] Docker (via Docker Desktop WSL integration)
- [x] AWS CLI v2
- [x] kubectl
- [x] Helm
- [x] Terraform via tfenv (1.9.5)
- [ ] Node.js — *intentionally skipped, not needed*

### Accounts

- [x] GitHub (`ayalmauda-ai`) — SSH authenticated
- [x] Docker Hub (`ayalm`) — access token created
- [x] AWS account — billing on, IAM user `jenkins-deploy` configured
- [x] Jira — reused from Lesson 47
- [x] SMTP / email for Jenkins notifications

### AWS one-time infrastructure

- [x] S3 bucket `ayal-tfstate-devops-final` (us-east-1, versioning enabled)
- [x] DynamoDB table `tfstate-lock` (LockID partition key, on-demand)

---

## Architecture quick-reference

```
Developer push → GitHub → Jenkins
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         Engine CI      CLI CI       [shared scripts]
         lint→test→     test→pkg→     detect-changes.sh
         build→push     build→push    bump-version.sh
              │             │
              ▼             ▼
         Docker Hub     GitHub Releases
         ayalm/engine   cli-vX.Y.Z.whl
         ayalm/cli
              └──────┬──────┘
                     ▼
           CD Pipeline (sequenced):
           Terraform → Ansible → kubectl
                     │
                     ▼
              AWS EKS cluster
              ├── StatefulSet (TCP probes, no /health)
              ├── PVC per pod via volumeClaimTemplates
              └── ingress-nginx (NLB)
                     │
              ┌──────┴──────┐
              ▼             ▼
         Prometheus    App Ingress
         + Grafana     POST /api/<customer>/<workflow>
```

### Critical contracts (the AI traps)

1. **One VERSION file** at repo root — both engine and CLI Dockerfiles read it via build-arg. Only engine-CI writes it.
2. **StatefulSet, not Deployment** — `volumeClaimTemplates` for per-pod PVCs, headless Service for stable DNS, **TCP probes** (no `/health` endpoint exists in the engine).
3. **Strict CD sequencing** — Terraform → Ansible → kubectl, sequential stages in one Jenkinsfile.
4. **Conditional rebuilds** — handled by `jenkins/shared/detect-changes.sh`.
5. **Two CI pipelines, shared version** — engine-ci writes `VERSION`; cli-ci reads only.
6. **Strict repo structure** — `engine/ cli/ docker/ k8s/ terraform/ ansible/ jenkins/ monitoring/` plus `VERSION`, `README.md`.

---

## Session log

### 2026-05-04 — Session 1 (Opus 4.7)
- Built full roadmap document (`DevOps_Final_Roadmap.docx`).
- Started Phase 0 walkthrough.
- Discovery script identified missing tools.

### 2026-05-19 — Session 2 (Opus 4.7)
- Investigated base project; **corrected URL to `gagishmagi/seyoawe-community`** (upstream was deleted/moved).
- Confirmed the project is Python + closed Linux binary engine, not pure Python.
- Verified engine runs locally (`./run.sh linux` → Flask on :8080); no `/health` endpoint exists.
- **Decision:** TCP-socket probes for K8s liveness, POST connection-reset probe for readiness.
- Designed and tested Phase 6 (version coupling) with nine scenarios; all pass.
- Created `phase6/` folder with drop-in scripts, Jenkinsfiles, test script, and README snippet.
- **Stopped at:** Phase 6 complete.

### 2026-05-20 — Session 3 (Sonnet 4.6 via Cowork)
- Recovered Phase 6 files from `phase6/` folder (Claude Code terminal commits hadn't landed in repo).
- **Phase 7 (Terraform):** scaffolded `terraform/` with backend, providers, variables, vpc, eks, outputs. `terraform init -backend=false` + `terraform validate` both pass. Lock file committed.
- **Phase 8 (Ansible):** created `ansible/ansible.cfg`, `inventory/hosts.ini`, `playbooks/configure-eks.yml` (updates kubeconfig, installs ingress-nginx via Helm).
- **Phase 9 (CD pipeline):** created `jenkins/Jenkinsfile.cd` — three strictly sequential stages: Terraform Apply → Ansible Configure → kubectl Deploy. Fixed `imagePullPolicy: IfNotPresent` in StatefulSet for EKS.
- **Open items closed:**
  - `cli/pyproject.toml` added (wheel build for Jenkinsfile.cli-ci)
  - `cli/tests/test_sawectl.py` — 17 unit tests, all pass
  - `tests/test_engine_smoke.py` — 2 integration tests (TCP probe + API layer probe), both pass
- **Stopped at:** All phases 0–9 done. All open items closed. Next: Phase 10 (Observability bonus).
- **Next action:** Use Phase 10 hand-off prompt above to start Prometheus + Grafana.

---

## Open questions / decisions to revisit

- [x] ~~Add `pyproject.toml` to `cli/` for pip-installable CLI~~ — done
- [x] ~~Add 6–10 unit tests for `sawectl.py`~~ — 17 tests, all pass
- [x] ~~Add integration smoke test for engine container~~ — 2 tests, both pass
- [ ] Decide on Route53 domain (~$12) vs NLB hostname for ingress — NLB hostname is fine for the course
- [ ] Whether to attempt RAG bonus (Phase 11) — decide after Phase 10
- [ ] EKS region: defaulted to `us-east-1`

## Cost reminders

- EKS control plane: ~$73/mo (always-on)
- 2× t3.medium nodes: ~$60/mo
- NAT gateway: ~$33/mo + data transfer
- **Total idle: ~$165/mo** → run `terraform destroy` between sessions. State stays in S3, you can `terraform apply` again whenever you resume.
