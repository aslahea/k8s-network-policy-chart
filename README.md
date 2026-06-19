# k8s-network-policy-chart

![Helm](https://img.shields.io/badge/Helm-v3-blue?logo=helm)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25+-326CE5?logo=kubernetes)
![License](https://img.shields.io/badge/license-MIT-green)

A **Helm chart** for deploying a zero-trust 3-tier application on Kubernetes with fully configurable **NetworkPolicies**.

> Default behaviour: all traffic is **denied**. You explicitly allow only what you need.

```
frontend  ──►  backend  ──►  database
```

---

## Requirements

- Kubernetes **1.25+**
- Helm **v3**

---

## Install

```bash
# Clone
git clone https://github.com/aslahea/k8s-network-policy-chart.git
cd k8s-network-policy-chart

# Install with defaults
helm install my-app .

# Verify
kubectl get pods,networkpolicies -n network-lab
```

---

## What Gets Deployed

| Resource | Name | Description |
|---|---|---|
| Namespace | `network-lab` | Isolated namespace for all resources |
| Pod | `frontend` | Simulates a frontend service |
| Pod | `backend` | Simulates a backend/API service |
| Pod | `database` | Simulates a database service |
| NetworkPolicy | `default-deny-all` | Blocks ALL traffic by default |
| NetworkPolicy | `allow-frontend-to-backend` | frontend → backend ✅ |
| NetworkPolicy | `allow-backend-egress-db` | backend can reach database ✅ |
| NetworkPolicy | `allow-backend-to-db` | database accepts traffic from backend ✅ |

---

## Configuration

Override any value using `--set` or a custom `-f values.yaml`.

| Parameter | Default | Description |
|---|---|---|
| `namespace` | `network-lab` | Namespace for all resources |
| `images.frontend` | `nginx` | Frontend container image |
| `images.backend` | `nginx` | Backend container image |
| `images.database` | `nginx` | Database container image |
| `networkPolicies.defaultDenyAll` | `true` | Block all ingress + egress |
| `networkPolicies.defaultDenyIngressOnly` | `false` | Block ingress only (lighter option) |
| `networkPolicies.allowFrontendToBackend` | `true` | Allow frontend → backend |
| `networkPolicies.allowBackendEgressToDb` | `true` | Allow backend → database (egress) |
| `networkPolicies.allowBackendToDb` | `true` | Allow database ← backend (ingress) |
| `ports.backend` | `[]` | Ports for frontend→backend (empty = all) |
| `ports.database` | `[]` | Ports for backend→database (empty = all) |

> ⚠️ Don't enable both `defaultDenyAll` and `defaultDenyIngressOnly` at the same time.

---

## Examples

### Use real images

```bash
helm install my-app . \
  --set images.frontend=myrepo/frontend:v1 \
  --set images.backend=myrepo/backend:v1 \
  --set images.database=postgres:15
```

### Lock to specific ports

```bash
helm install my-app . \
  --set "ports.backend[0].port=8080" \
  --set "ports.database[0].port=5432"
```

### Deploy to a different namespace

```bash
helm install my-app . --set namespace=staging
```

### Use a custom values file

```yaml
# my-values.yaml
namespace: production

images:
  frontend: gcr.io/myproject/frontend:1.0.0
  backend:  gcr.io/myproject/backend:1.0.0
  database: postgres:15-alpine

ports:
  backend:
    - protocol: TCP
      port: 8080
  database:
    - protocol: TCP
      port: 5432
```

```bash
helm install my-app . -f my-values.yaml
```

### Upgrade after changes

```bash
helm upgrade my-app . -f my-values.yaml
```

### Uninstall

```bash
helm uninstall my-app
kubectl delete namespace network-lab   # optional
```

---

## Project Structure

```
k8s-network-policy-chart/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── _helpers.tpl                   # shared label/namespace helpers
    ├── namespace.yaml
    ├── pods.yaml
    ├── default-deny.yaml
    ├── default-deny-ingress.yaml
    ├── allow-frontend-backend.yaml
    ├── allow-backend-egress-db.yaml
    └── allow-backend-to-db.yaml
```

---

## How NetworkPolicies Work

Kubernetes NetworkPolicies are **additive** — you start with deny-all and open only what you need.

```
┌─ namespace: network-lab ──────────────────────────────────┐
│                                                            │
│  [frontend] ──► allow-frontend-to-backend ──► [backend]  │
│                                                    │       │
│                           allow-backend-egress-db  │       │
│                           allow-backend-to-db      │       │
│                                                    ▼       │
│                                              [database]    │
│                                                            │
│  Everything else: BLOCKED by default-deny-all             │
└────────────────────────────────────────────────────────────┘
```

---

## License

MIT
