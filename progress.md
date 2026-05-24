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

Then attach both files plus, if relevant, the `phase6/` folder for the actual Phase 6 artifacts.

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
| K8s health probes | TCP-socket probes on port 8080 (canonical pattern when no /health endpoint exists — same approach as Postgres/Redis/MongoDB containers). Readiness uses an exec probe that sends a POST and checks for any 3xx/4xx response (proves the API layer is up, not just TCP). |
| CLI testing | `sawectl.py` is real Python source — we write 6–10 unit tests of argument parsing and workflow validation. Easy 10 points. |
| Engine testing | Integration smoke test: boot container, TCP probe :8080 with 30-second budget. |
| Version coupling | Unchanged from roadmap design — both images publish at same semver. |

---

## Model strategy (which Claude to use when)

| Phase | Recommended model | Reason |
|-------|-------------------|--------|
| 0 — Prerequisites & accounts | Sonnet 4.6 (or Haiku for quick lookups) | Standard installs, nothing novel |
| 1 — Repo structure | Sonnet 4.6 | Mechanical scaffolding |
| 2 — Containerization | Sonnet 4.6 | Standard multi-stage Dockerfiles |
| 3 — Kubernetes (StatefulSet) | Sonnet 4.6, escalate to Opus if probes/PVCs misbehave | StatefulSet trap is real |
| 4 — Engine CI Jenkinsfile | Sonnet 4.6 | Familiar from Lesson 47 |
| 5 — CLI CI Jenkinsfile | Sonnet 4.6 | Same pattern as engine |
| **6 — Version coupling logic** | **Opus 4.7** ✅ DONE | Designed and tested in Opus session 2026-05-19 |
| 7 — Terraform AWS EKS | Sonnet 4.6, Opus if IAM/state weirdness | Official modules do the heavy lifting |
| 8 — Ansible | Sonnet 4.6 | Standard playbook patterns |
| **9 — CD pipeline sequencing** | **Opus 4.7** | Other big trap — stage ordering, rollback |
| 10 — Observability (bonus) | Sonnet 4.6 | helm install + dashboards |
| 11 — AI RAG bonus | Opus 4.7 | Architecture territory |
| **Stuck >20 min on anything** | **Opus 4.7** | Deep debug pays off |

> **Important:** Models can't be switched mid-session in Cowork. Start a new session to switch. For bulk code work, use Claude terminal (Claude Code) in WSL — it's Sonnet-based and ideal for mechanical file creation.

---

## Status board

| # | Phase | Status | Last touched | Notes |
|---|-------|--------|--------------|-------|
| 0 | Prerequisites & accounts | ✅ Done | 2026-05-19 | Most tools installed (see Phase 0 checklist below) |
| 1 | Repo structure & base project | ✅ Done | 2026-05-19 | User report |
| 2 | Containerization | ✅ Done | 2026-05-19 | User report |
| 3 | Kubernetes manifests (StatefulSet) | ✅ Done | 2026-05-19 | TCP probes used (no /health) |
| 4 | CI pipeline for Engine | ✅ Done | 2026-05-19 | Phase 6 deliverables include refined Jenkinsfile.engine-ci |
| 5 | CI pipeline for CLI | ✅ Done | 2026-05-19 | Same as above for Jenkinsfile.cli-ci |
| **6** | **Version coupling logic** | **✅ Done** | **2026-05-19** | **Design + code + local tests complete. See `phase6/` folder.** |
| 7 | Terraform AWS EKS | ✅ Done | 2026-05-20 | `terraform validate` passes; lock file committed |
| 8 | Ansible | ✅ Done | 2026-05-20 | `playbooks/configure-eks.yml` updates kubeconfig + installs ingress-nginx |
| 9 | CD pipeline | ✅ Done | 2026-05-20 | `jenkins/Jenkinsfile.cd` — Terraform → Ansible → kubectl |
| **10** | **Observability bonus** | **✅ Done** | **2026-05-24** | **kube-prometheus-stack + Grafana dashboard. See `monitoring/` folder.** |
| 11 | AI RAG bonus | ⬜ Not started | — | Optional — decide after project submission |

**Status legend:** ⬜ Not started · 🟡 In progress · 🔴 Blocked · ✅ Done

---

## Phase 10 deliverables (monitoring/)

All files live in `monitoring/` at the repo root.

```
monitoring/
├── values-prometheus.yaml    # Helm values for kube-prometheus-stack
├── dashboard-configmap.yaml  # Grafana dashboard as K8s ConfigMap (auto-loaded by sidecar)
├── install.sh                # One-command deploy (helm repo add → kubectl apply → helm upgrade)
└── uninstall.sh              # Clean removal before terraform destroy
```

### What's included

**Prometheus** collects metrics from:
- kube-state-metrics (pod phase, restart counts, replica counts)
- cAdvisor via kubelet (CPU, memory, network per container)
- node-exporter (host-level: disk, load, filesystem)
- Additional scrape job targeting `app=seyoawe-engine` pods on port 8080 (engine has no /metrics — scrape errors expected; pod-level metrics are the real source)

**Grafana** is accessible at `http://<NLB-hostname>/grafana`
- Username: `admin` / Password: `DevOps2026!`
- Dashboard **seyoawe Engine – Overview** auto-loads from ConfigMap:
  - Panel 1: Pod Availability (green/red stat)
  - Panel 2: Pod Restarts counter
  - Panel 3: CPU Usage (millicores, per pod)
  - Panel 4: Memory Usage (MB, per pod)
  - Panel 5: Network I/O — RX + TX bytes/s

### How to deploy

```bash
# From your repo root in WSL
cd ~/study/final-project

# Copy files from phase6 workspace (if not already in repo):
P6="/mnt/c/Users/ayalm/AppData/Local/Packages/Claude_pzs8sxrjxfjjc/LocalCache/Roaming/Claude/local-agent-mode-sessions/3f31775a-cad3-463c-b1c9-de9389fc8829/452a0b3d-bd86-4e38-bb5c-1ae144c21f59/local_e9249ffe-25f9-4325-817a-8d345749f237/outputs/phase6"
mkdir -p monitoring
cp "$P6/monitoring/values-prometheus.yaml"   monitoring/
cp "$P6/monitoring/dashboard-configmap.yaml" monitoring/
cp "$P6/monitoring/install.sh"               monitoring/
cp "$P6/monitoring/uninstall.sh"             monitoring/
chmod +x monitoring/install.sh monitoring/uninstall.sh

# Make sure EKS is up and kubectl can reach it
kubectl get nodes

# Deploy (takes 3-5 minutes)
bash monitoring/install.sh
```

### IMPORTANT: Before `terraform destroy`

Always run `bash monitoring/uninstall.sh` first, or the EBS volumes (Prometheus data, Grafana state) will orphan in AWS and continue costing money.

---

## Phase 6 deliverables (drop-in to your repo)

All files live in the `phase6/` folder. To adopt them into your repo:

```bash
cd ~/study/final-project

mkdir -p jenkins/shared
cp /path/to/phase6/jenkins/shared/detect-changes.sh jenkins/shared/
cp /path/to/phase6/jenkins/shared/bump-version.sh   jenkins/shared/
chmod +x jenkins/shared/*.sh

cp /path/to/phase6/jenkins/Jenkinsfile.engine-ci jenkins/
cp /path/to/phase6/jenkins/Jenkinsfile.cli-ci    jenkins/

[ -f VERSION ] || cp /path/to/phase6/VERSION ./VERSION

bash /path/to/phase6/test-version-coupling.sh jenkins/shared
# Expect: "ALL SCENARIOS PASSED ✓"

cat /path/to/phase6/README-version-coupling.md >> README.md
```

### Phase 6 design at a glance

Three rules: **one source of truth (`VERSION`), one writer (engine-ci on main only), `VERSION` changes trigger both pipelines.**

Test results from 2026-05-19: all 8 scenarios pass.

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
- [x] Terraform via tfenv (1.9.5 installed per `.tfenv/versions/`)
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

## Architecture quick-reference (updated)

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
         (/grafana     (NLB hostname)
          via NLB)
```

### Critical contracts (the AI traps)

1. **One VERSION file** at repo root — both engine and CLI Dockerfiles read it via build-arg. Only engine-CI writes it.
2. **StatefulSet, not Deployment** — `volumeClaimTemplates` for per-pod PVCs, headless Service for stable DNS, **TCP probes** (no `/health` endpoint).
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
- Investigated base project; corrected URL to `gagishmagi/seyoawe-community`.
- Confirmed hybrid Python + closed binary engine, port 8080, no `/health`.
- Designed and tested Phase 6 (version coupling) — 8 scenarios, all pass.
- **Stopped at:** Phase 6 complete.

### 2026-05-20 — Session 3 (Sonnet 4.6 via Cowork)
- Phases 7–9 complete (Terraform, Ansible, CD pipeline).
- Open items closed: `pyproject.toml`, 17 unit tests, 2 integration tests.
- Committed as `ff37dcb`.
- **Stopped at:** All phases 0–9 done.

### 2026-05-24 — Session 4 (Sonnet 4.6 via Cowork)
- Phase 10 (Observability bonus): created `monitoring/` folder with full Prometheus + Grafana stack.
- Grafana exposed at `/grafana` path on existing ingress-nginx NLB (no Route53 needed).
- Dashboard: **seyoawe Engine – Overview** with 5 panels (pod availability, restarts, CPU, memory, network I/O).
- Engine binary has no `/metrics` endpoint → pod-level metrics (kube-state-metrics + cAdvisor) used instead; documented as standard pattern for closed-source workloads.
- **Next action:** Copy `monitoring/` files to repo, commit, then run `bash monitoring/install.sh` against live EKS cluster.

---

## Open questions / decisions to revisit

- ~~Add `pyproject.toml` to `cli/`~~ — done
- ~~Add 6–10 unit tests for `sawectl.py`~~ — 17 tests, all pass
- ~~Add integration smoke test for engine container~~ — 2 tests, both pass
- Route53 domain (~$12) vs NLB hostname — **NLB hostname is fine for the course**
- Phase 11 RAG bonus — decide after project submission

## Cost reminders

- EKS control plane: ~$73/mo (always-on)
- 2× t3.medium nodes: ~$60/mo
- NAT gateway: ~$33/mo + data transfer
- **Total idle: ~$165/mo** → run `terraform destroy` between sessions. State stays in S3.
- **Run `bash monitoring/uninstall.sh` BEFORE `terraform destroy`** — prevents orphaned EBS volumes.
