# DevOps Final Project

**Student:** Ayal Mauda  
**GitHub:** [ayalmauda-ai](https://github.com/ayalmauda-ai)  
**Docker Hub:** [ayalm](https://hub.docker.com/u/ayalm)  
**Base project:** [gagishmagi/seyoawe-community](https://github.com/gagishmagi/seyoawe-community)

---

## Overview

This project takes an existing open-source application and wraps a full DevOps lifecycle around it from scratch. The work covers: containerizing the application, writing automated CI/CD pipelines, provisioning cloud infrastructure with code, configuring a Kubernetes cluster, and adding live monitoring with Prometheus and Grafana.

---

## Architecture

```
Developer push
      │
      ▼
   GitHub ──────────────────────────────────────────┐
      │                                              │
      ▼                                          (webhook)
   Jenkins                                           │
      │                                              │
   ┌──┴──────────────┬──────────────────┐            │
   ▼                 ▼                  ▼            │
Engine CI         CLI CI          CD Pipeline ◄──────┘
(Jenkinsfile      (Jenkinsfile    (Jenkinsfile.cd)
 .engine-ci)       .cli-ci)
   │                 │                  │
   │  detect-changes.sh                 │
   │  bump-version.sh                   │
   │  VERSION (shared)                  │
   │                 │       ┌──────────┴──────────────┐
   ▼                 ▼       ▼           ▼             ▼
Docker Hub      Docker Hub  Terraform  Ansible      kubectl
ayalm/          ayalm/      VPC + EKS  kubeconfig   apply
seyoawe-engine  seyoawe-cli cluster    + ingress-   k8s/*.yaml
:1.0.0          :1.0.0                 nginx
                                   │
                                   ▼
                             AWS EKS Cluster
                             ┌──────────────────────────┐
                             │  StatefulSet (engine)    │
                             │  ├── engine-0 + PVC      │
                             │  └── engine-1 + PVC      │
                             │  Service (ClusterIP)     │
                             │  Ingress (NLB hostname)  │
                             │  ────────────────────    │
                             │  monitoring/             │
                             │  ├── Prometheus          │
                             │  └── Grafana (/grafana)  │
                             └──────────────────────────┘
```

---

## Repository Structure

```
devops-final-project/
├── VERSION                          # Single source of truth for the semantic version
├── README.md                        # This file
│
├── engine/                          # Application engine — binary + Python modules
│   ├── seyoawe.linux                # Compiled engine binary (port 8080)
│   ├── modules/                     # Python plugins loaded at runtime
│   ├── workflows/                   # YAML workflow definitions
│   └── configuration/               # Runtime configuration files
│
├── cli/                             # CLI tool (sawectl)
│   ├── sawectl/sawectl.py           # Main CLI source
│   ├── pyproject.toml               # Python packaging config for wheel builds
│   └── tests/
│       └── test_sawectl.py          # 17 unit tests
│
├── docker/
│   ├── engine.Dockerfile            # Builds the engine container image
│   └── cli.Dockerfile               # Builds the CLI container image
│
├── k8s/                             # Kubernetes manifests
│   ├── statefulset.yaml             # Engine StatefulSet with TCP probes and PVCs
│   ├── service.yaml                 # Internal ClusterIP service
│   ├── ingress.yaml                 # External access via ingress-nginx
│   └── configmap.yaml               # Configuration mounted into pods at runtime
│
├── terraform/                       # AWS infrastructure as code
│   ├── backend.tf                   # Remote state: S3 bucket + DynamoDB lock
│   ├── providers.tf                 # AWS provider
│   ├── variables.tf                 # Configurable values (region, instance type, etc.)
│   ├── vpc.tf                       # VPC, subnets, NAT gateway
│   ├── eks.tf                       # EKS cluster and managed node group
│   └── outputs.tf                   # Cluster name and endpoint exposed for Ansible
│
├── ansible/
│   ├── ansible.cfg                  # Ansible settings
│   ├── inventory/hosts.ini          # Localhost inventory (runs on the Jenkins agent)
│   └── playbooks/
│       └── configure-eks.yml        # Updates kubeconfig, installs ingress-nginx
│
├── jenkins/
│   ├── Jenkinsfile.engine-ci        # CI pipeline for the engine
│   ├── Jenkinsfile.cli-ci           # CI pipeline for the CLI
│   ├── Jenkinsfile.cd               # CD pipeline: Terraform → Ansible → kubectl
│   └── shared/
│       ├── detect-changes.sh        # Skips rebuild if no relevant files changed
│       └── bump-version.sh          # Increments PATCH, commits with [skip ci], pushes
│
├── monitoring/
│   ├── values-prometheus.yaml       # Helm values for kube-prometheus-stack
│   ├── dashboard-configmap.yaml     # Grafana dashboard auto-loaded via ConfigMap label
│   ├── install.sh                   # Deploys the full monitoring stack
│   └── uninstall.sh                 # Removes it cleanly before terraform destroy
│
└── tests/
    └── test_engine_smoke.py         # Integration test: TCP probe on port 8080
```

---

## What Was Built

### Containerization

The application engine and CLI tool were each packaged into their own Docker image. The engine is a compiled binary that writes state to disk, so it was deployed as a **StatefulSet** — giving each pod its own dedicated persistent volume that survives restarts. This is different from a standard Deployment, where pods share or lose storage on restart.

The engine has no `/health` HTTP endpoint, so **TCP socket probes** on port 8080 were used for liveness and readiness checks. This is the standard Kubernetes pattern for workloads that do not expose a health path.

Both images were pushed to Docker Hub:
- `ayalm/seyoawe-engine:1.0.0`
- `ayalm/seyoawe-cli:1.0.0`

### CI Pipelines

Two separate Jenkins pipelines were written — one for the engine, one for the CLI. A shared script (`detect-changes.sh`) runs at the start of each pipeline and checks which files changed in the latest commit. If nothing relevant changed, the pipeline exits early. This prevents unnecessary image builds when only unrelated code was modified.

The engine pipeline: lints Python modules → builds the Docker image → runs a smoke test (TCP probe on the booted container) → pushes to Docker Hub → bumps the version.

The CLI pipeline: runs 17 unit tests with pytest → builds a Python wheel package → builds the Docker image → pushes to Docker Hub → publishes a GitHub Release with the `.whl` file attached.

### Version Coupling

Both images always share the same version tag. A single `VERSION` file at the repo root is the only place the version is stored. Only the engine pipeline writes to it. When it bumps the version and pushes the commit, both pipelines detect the `VERSION` change and rebuild — producing matching `engine:1.0.1` and `cli:1.0.1` tags.

The `bump-version.sh` script guards against infinite loops, double-bumps, and race conditions between concurrent pipeline runs.

### Cloud Infrastructure with Terraform

All AWS infrastructure is defined as code in `terraform/`. A `terraform apply` creates:

- A VPC with public and private subnets across two availability zones
- A single NAT gateway for outbound internet access from the private subnets
- An EKS cluster (Kubernetes 1.30) with two `t3.medium` worker nodes

Terraform state is stored in S3 (`ayal-tfstate-devops-final`) with a DynamoDB table for locking, so the Jenkins CD pipeline can apply changes safely without local state files.

### Configuration Management with Ansible

After Terraform creates the cluster, an Ansible playbook (`configure-eks.yml`) runs to configure it. It reads the cluster name directly from `terraform output` — nothing is hardcoded. It then updates `~/.kube/config` and installs ingress-nginx via Helm so that the Kubernetes Ingress manifests have a controller to act on them.

The CD pipeline runs its three stages in strict order — Terraform, then Ansible, then kubectl — because each step depends on the previous one completing successfully.

### Monitoring (Bonus)

Prometheus and Grafana were deployed using the `kube-prometheus-stack` Helm chart. Since the engine binary exposes no `/metrics` endpoint, the Grafana dashboard was built entirely from pod-level metrics collected automatically by Kubernetes: pod availability and restarts from kube-state-metrics, and CPU, memory, and network usage from cAdvisor.

Grafana is accessible at `/grafana` on the same load balancer hostname as the application. The dashboard definition is stored in a Kubernetes ConfigMap and loaded automatically at startup — no manual import needed.

---

## Key Design Decisions

**StatefulSet over Deployment** — the engine writes state to disk; each pod needs its own dedicated persistent volume that follows it through restarts.

**TCP probes over HTTP** — the engine binary exposes no `/health` endpoint; TCP socket probe on port 8080 is the correct substitute.

**One VERSION file, one writer** — prevents version drift between the two Docker images. The CLI pipeline reads the file but never modifies it.

**Sequential CD stages** — Terraform must finish before Ansible (the cluster must exist); Ansible must finish before kubectl (ingress-nginx must be running for the Ingress resource to work).

**Pod-level metrics for monitoring** — the engine cannot be instrumented directly; kube-state-metrics and cAdvisor provide full pod-level visibility without modifying the binary.

---

## Running Locally

To run this project on your own machine, start by cloning the repository:

```bash
git clone https://github.com/ayalmauda-ai/devops-final-project.git
cd devops-final-project
```

**Run the engine with Docker:**

Docker Desktop (or Docker Engine on Linux) must be installed. Then:

```bash
docker pull ayalm/engine:1.0.0
docker run -d -p 18080:8080 ayalm/engine:1.0.0
```

The engine will be running at `http://localhost:18080`. It accepts POST requests only:

```bash
curl -X POST http://localhost:18080/api/<customer_id>/<workflow_name>
```

Or use Postman — set method to POST and hit the same URL.

**Run the CLI:**

```bash
docker pull ayalm/cli:1.0.0
docker run --rm ayalm/cli:1.0.0 sawectl --help
```

**Run on a local Kubernetes cluster (Minikube):**

Minikube must be installed and running (`minikube start`). Then:

```bash
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/statefulset.yaml
kubectl get pods -w
```

Wait until pods show `Running`, then check the engine is up:

```bash
kubectl exec -it engine-0 -- nc -zv localhost 8080
```

**Run the CLI unit tests:**

```bash
cd cli
pip install pyyaml jsonschema requests pytest
pytest tests/ -v
# Expected: 17 passed
```
