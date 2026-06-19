# network-policy-chart

> A **reusable Helm chart** that deploys a 3-tier application (frontend / backend / database)
> inside a dedicated namespace with fully configurable Kubernetes **NetworkPolicies**.

---

## Table of Contents

1. [What This Chart Does](#what-this-chart-does)  
2. [Directory Structure](#directory-structure)  
3. [Prerequisites](#prerequisites)  
4. [Quick Start](#quick-start)  
5. [Configuration Reference](#configuration-reference)  
6. [How the Network Policies Work](#how-the-network-policies-work)  
7. [Overriding Values at Install Time](#overriding-values-at-install-time)  
8. [Common Usage Examples](#common-usage-examples)  
9. [Pushing to Git](#pushing-to-git)  

---

## What This Chart Does

| Resource | Count | Description |
|---|---|---|
| `Namespace` | 1 | Isolated namespace for all resources |
| `Pod` | 3 | frontend · backend · database |
| `NetworkPolicy` | up to 5 | Configurable via `values.yaml` flags |

**Default traffic model (zero-trust):**

```
Internet / other namespaces
        │
        ▼  BLOCKED (default-deny-all)
┌───────────────────────────────┐  namespace: network-lab
│  frontend ──► backend ──► database
│   (allowed)         (allowed)
└───────────────────────────────┘
```

---

## Directory Structure

```
week47-k8s-security/
├── 02-networkpolicies/          ← original raw YAML files (unchanged)
│   ├── pods.yaml
│   ├── default-deny.yaml
│   ├── default-deny-ingress.yaml
│   ├── allow-frontend-backend.yaml
│   ├── allow-backend-egress-db.yaml
│   └── allow-backend-to-db
│
└── network-policy-chart/        ← Helm chart (this repo)
    ├── Chart.yaml
    ├── values.yaml
    ├── .helmignore
    ├── README.md
    └── templates/
        ├── _helpers.tpl
        ├── namespace.yaml
        ├── pods.yaml
        ├── default-deny.yaml
        ├── default-deny-ingress.yaml
        ├── allow-frontend-backend.yaml
        ├── allow-backend-egress-db.yaml
        └── allow-backend-to-db.yaml
```

---

## Prerequisites

| Tool | Minimum Version | Check |
|---|---|---|
| `kubectl` | 1.25+ | `kubectl version --client` |
| `helm` | 3.x | `helm version` |
| A running cluster | — | `kubectl cluster-info` |

---

## Quick Start

```bash
# 1. Clone the repo (or cd into the folder)
cd week47-k8s-security/

# 2. Dry-run first — inspect what will be created
helm template my-app ./network-policy-chart

# 3. Install with default values
helm install my-app ./network-policy-chart

# 4. Verify
kubectl get pods,networkpolicies -n network-lab
```

---

## Configuration Reference

Edit `values.yaml` or pass `--set` flags at install time.

### `namespace`

| Key | Type | Default | Description |
|---|---|---|---|
| `namespace` | string | `network-lab` | Kubernetes namespace for all resources |

### `images`

| Key | Type | Default | Description |
|---|---|---|---|
| `images.frontend` | string | `nginx` | Container image for the frontend pod |
| `images.backend` | string | `nginx` | Container image for the backend pod |
| `images.database` | string | `nginx` | Container image for the database pod |

### `networkPolicies`

| Key | Type | Default | Description |
|---|---|---|---|
| `networkPolicies.defaultDenyAll` | bool | `true` | Block ALL ingress & egress (zero-trust baseline) |
| `networkPolicies.defaultDenyIngressOnly` | bool | `false` | Block only ingress (lighter alternative) |
| `networkPolicies.allowFrontendToBackend` | bool | `true` | Allow frontend → backend |
| `networkPolicies.allowBackendEgressToDb` | bool | `true` | Allow backend to egress toward database |
| `networkPolicies.allowBackendToDb` | bool | `true` | Allow database to accept ingress from backend |

> **⚠ Warning:** Do not enable both `defaultDenyAll` and `defaultDenyIngressOnly` simultaneously.

### `ports`

| Key | Type | Default | Description |
|---|---|---|---|
| `ports.backend` | list | `[]` | Port rules for frontend→backend (empty = all ports) |
| `ports.database` | list | `[]` | Port rules for backend→database (empty = all ports) |

**Port list entry format:**
```yaml
ports:
  database:
    - protocol: TCP
      port: 5432
```

---

## How the Network Policies Work

### 1. `default-deny-all` (baseline)
```
podSelector: {}   →  matches EVERY pod
policyTypes: [Ingress, Egress]   →  blocks everything
```
This is applied first. Nothing can talk to anything unless explicitly allowed.

### 2. `allow-frontend-to-backend`
```
Applied ON:  backend pod   (Ingress policy)
Allows:      traffic FROM frontend pod
```

### 3. `allow-backend-egress-db`
```
Applied ON:  backend pod   (Egress policy)
Allows:      traffic TO database pod
```

### 4. `allow-backend-to-db`
```
Applied ON:  database pod  (Ingress policy)
Allows:      traffic FROM backend pod
```

> Policies 3 and 4 work **together** — both sides of the connection must be permitted.

### 5. `default-deny-ingress` (optional)
A lighter alternative to `default-deny-all`. Only blocks incoming traffic; outgoing traffic is unrestricted.

---

## Overriding Values at Install Time

### Using `--set` flags

```bash
# Change namespace only
helm install my-app ./network-policy-chart --set namespace=production

# Use real images instead of nginx
helm install my-app ./network-policy-chart \
  --set images.frontend=myrepo/frontend:v2 \
  --set images.backend=myrepo/backend:v2 \
  --set images.database=postgres:15

# Pin database port to 5432
helm install my-app ./network-policy-chart \
  --set "ports.database[0].protocol=TCP" \
  --set "ports.database[0].port=5432"

# Disable the strict deny-all (use deny-ingress only)
helm install my-app ./network-policy-chart \
  --set networkPolicies.defaultDenyAll=false \
  --set networkPolicies.defaultDenyIngressOnly=true
```

### Using a custom `values.yaml`

```bash
# Create an override file
cat > my-values.yaml <<EOF
namespace: staging

images:
  frontend: myrepo/frontend:v2
  backend:  myrepo/backend:v2
  database: postgres:15

ports:
  database:
    - protocol: TCP
      port: 5432
  backend:
    - protocol: TCP
      port: 8080
EOF

helm install my-app ./network-policy-chart -f my-values.yaml
```

### Upgrading after changes

```bash
helm upgrade my-app ./network-policy-chart -f my-values.yaml
```

### Uninstalling

```bash
helm uninstall my-app

# If you also want to delete the namespace manually:
kubectl delete namespace network-lab
```

---

## Common Usage Examples

### Example A — Production with real images and locked ports
```yaml
# prod-values.yaml
namespace: production

images:
  frontend: gcr.io/myproject/frontend:1.0.0
  backend:  gcr.io/myproject/backend:1.0.0
  database: postgres:15-alpine

networkPolicies:
  defaultDenyAll: true
  defaultDenyIngressOnly: false
  allowFrontendToBackend: true
  allowBackendEgressToDb: true
  allowBackendToDb: true

ports:
  backend:
    - protocol: TCP
      port: 8080
  database:
    - protocol: TCP
      port: 5432
```
```bash
helm install prod-app ./network-policy-chart -f prod-values.yaml -n production --create-namespace
```

### Example B — Ingress-only lockdown (keep egress open)
```bash
helm install dev-app ./network-policy-chart \
  --set networkPolicies.defaultDenyAll=false \
  --set networkPolicies.defaultDenyIngressOnly=true \
  --set namespace=dev
```

---

## Pushing to Git

The **original raw YAML files** stay in `02-networkpolicies/` unchanged.  
The Helm chart lives in `network-policy-chart/` as a separate, reusable directory.

### Step-by-step: push the chart to a new Git repo

```bash
# 1. Go into the chart folder
cd /home/ubuntu/Brototype/June/week47-k8s-security/network-policy-chart

# 2. Initialize git
git init

# 3. Add all files
git add .

# 4. First commit
git commit -m "feat: add network-policy-chart Helm chart"

# 5. Create a repo on GitHub (or GitLab) and copy the remote URL, then:
git remote add origin https://github.com/YOUR-USERNAME/network-policy-chart.git

# 6. Push
git branch -M main
git push -u origin main
```

### Step-by-step: push the entire week47 folder to a monorepo

```bash
cd /home/ubuntu/Brototype/June/week47-k8s-security

git init
git add .
git commit -m "feat: k8s network policy lab + reusable helm chart"

git remote add origin https://github.com/YOUR-USERNAME/week47-k8s-security.git
git branch -M main
git push -u origin main
```

> **Tip:** Add a `.gitignore` at the root:
> ```
> # .gitignore
> *.tgz          # packaged helm charts
> .DS_Store
> ```

---

*Chart version: 0.1.0 — maintained alongside the `02-networkpolicies` study lab.*
