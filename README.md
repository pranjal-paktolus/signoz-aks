# AKS GitOps Platform

A production-grade GitOps platform on Azure Kubernetes Service (AKS) using **Terraform**, **ArgoCD**, **Helm**, and **GitHub Actions**.

---

## Repository Structure

```
.
├── .github/workflows/
│   ├── ci.yaml               ← Build → Scan → Push Docker image + bump Helm tag
│   ├── terraform.yaml        ← Plan on PR, Apply on merge to main
│   ├── argocd-bootstrap.yaml ← Install ArgoCD + register root App-of-Apps
│   └── helm-lint.yaml        ← Lint + kubeconform validate all charts on PRs
│
├── apps/node-app/            ← Node.js application source + Dockerfile
├── charts/node-app/          ← Helm chart supporting Prometheus or SigNoz modes
├── argocd/
│   ├── root-app.yaml         ← App-of-Apps pointing to argocd/apps/
│   ├── signoz-root-app.yaml  ← App-of-Apps for the dedicated SigNoz AKS
│   ├── apps/
│       ├── node-app.yaml     ← ArgoCD app for the Node app
│       └── monitoring.yaml   ← ArgoCD app for kube-prometheus-stack
│   └── signoz-apps/
│       ├── monitoring.yaml   ← ArgoCD app for the SigNoz backend
│       ├── k8s-infra.yaml    ← ArgoCD app for SigNoz k8s-infra collectors
│       └── node-app.yaml     ← Optional sample app wired to SigNoz
└── terraform/
    ├── dev/                  ← Existing AKS cluster + ACR + Log Analytics Terraform
    └── signoz/               ← Dedicated AKS environment for SigNoz
```

---

## GitHub Actions Workflows

### 1. `ci.yaml` — CI (Build → Scan → Push)

**Trigger:** push to `main` **or** pull-request touching `apps/node-app/**`

| Step | What it does |
|------|-------------|
| Checkout | Full clone |
| Derive tag | `GITHUB_SHA[:8]` used as the image tag |
| ACR login | Uses `ACR_LOGIN_SERVER / ACR_USERNAME / ACR_PASSWORD` secrets |
| Docker build | Builds `node-app:<sha>` and `node-app:latest` |
| Trivy scan | Fails on CRITICAL/HIGH CVEs (unfixed ones are ignored) |
| Push | Pushes both tags — **only on merge to main, not on PRs** |
| Bump Helm tag | `sed` updates `charts/node-app/values.yaml`, commits & pushes → ArgoCD auto-syncs |

### 2. `terraform.yaml` — Infrastructure Provisioning

**Trigger:** push/PR touching `terraform/**`

| Step | What it does |
|------|-------------|
| `terraform fmt` | Format check (warn, don't block) |
| `terraform init` | Connects to Azure Storage remote backend |
| `terraform validate` | Schema validation |
| `terraform plan` | Plans and saves to `tfplan`; output posted as PR comment |
| `terraform apply` | Runs `tfplan` — **only on merge to main** |

Uses a `concurrency` lock to prevent parallel state mutations.

### 3. `argocd-bootstrap.yaml` — Bootstrap GitOps

**Trigger:** push touching `argocd/**` or manual `workflow_dispatch`

| Step | What it does |
|------|-------------|
| Azure login | OIDC via `AZURE_CREDENTIALS` secret |
| AKS context | Fetches kubeconfig for the target cluster |
| Install ArgoCD | Idempotent — skips if already present |
| Apply root-app | Registers `argocd/root-app.yaml` (App-of-Apps) |

After this runs, ArgoCD automatically manages everything under `argocd/apps/`.

---

## Monitoring Stack

This repository now supports two isolated monitoring lanes:

- `argocd/apps/monitoring.yaml` keeps the existing Prometheus + Grafana stack for the current AKS cluster.
- `argocd/signoz-root-app.yaml` bootstraps a separate app-of-apps for the dedicated SigNoz AKS cluster.
- `argocd/signoz-apps/monitoring.yaml` installs the self-hosted SigNoz backend on that new cluster.
- `argocd/signoz-apps/k8s-infra.yaml` installs SigNoz's `k8s-infra` chart for AKS metrics, logs, events, and OTLP ingestion.
- `argocd/signoz-apps/node-app.yaml` is an optional sample workload configured to emit traces to SigNoz.

The shared `node-app` Helm chart now supports both modes:

- Default values keep Prometheus annotations, `ServiceMonitor`, and `PrometheusRule` resources for the existing cluster.
- SigNoz-specific overrides enable OpenTelemetry export and SigNoz scrape annotations only for the dedicated SigNoz cluster.

This keeps the new SigNoz rollout separate from the existing Prometheus/Grafana AKS with no manifest overlap.

### 4. `helm-lint.yaml` — Chart Quality Gate

**Trigger:** push/PR touching `charts/**`

| Step | What it does |
|------|-------------|
| chart-testing `ct lint` | Lints only changed charts |
| `helm template` | Dry-run renders all charts |
| kubeconform | Validates rendered YAML against Kubernetes 1.29 schema |

---

## Required GitHub Secrets

| Secret | Used by | Value |
|--------|---------|-------|
| `ACR_LOGIN_SERVER` | ci.yaml | e.g. `aksgitopsdevacr.azurecr.io` |
| `ACR_USERNAME` | ci.yaml | ACR admin username |
| `ACR_PASSWORD` | ci.yaml | ACR admin password |
| `ARM_CLIENT_ID` | terraform.yaml | Service principal client ID |
| `ARM_CLIENT_SECRET` | terraform.yaml | Service principal client secret |
| `ARM_SUBSCRIPTION_ID` | terraform.yaml | Azure subscription ID |
| `ARM_TENANT_ID` | terraform.yaml | Azure tenant ID |
| `AZURE_CREDENTIALS` | argocd-bootstrap.yaml | JSON from `az ad sp create-for-rbac` |
| `AKS_RESOURCE_GROUP` | argocd-bootstrap.yaml | Resource group name |
| `AKS_CLUSTER_NAME` | argocd-bootstrap.yaml | AKS cluster name |

---

## Deployment Flow

```
Developer pushes code
        │
        ▼
[ci.yaml] Build & scan Docker image
        │  (fails if CRITICAL/HIGH CVE)
        ▼
Push image → ACR
        │
        ▼
Bump charts/node-app/values.yaml (image tag)
        │
        ▼
ArgoCD detects values.yaml change → syncs Helm chart → rolling update on AKS
```

Infrastructure changes flow through:
```
Edit terraform/ → open PR → [terraform.yaml] posts plan comment → merge → apply
```
