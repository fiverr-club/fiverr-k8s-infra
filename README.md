# Fiverr Club Kubernetes & Helm Infrastructure (`fiverr-k8s-infra`)

Production-ready **Kubernetes (Kustomize)**, **Helm v3 Umbrella Chart**, and **Docker Compose** infrastructure repository for the **Fiverr Club** Freelance Marketplace Ecosystem.

---

## Cluster Topology

| Workload | Port | Type | Database / Backing Store | Autoscaling |
|---|---|---|---|---|
| `fiverr-web` | `3000` | Next.js 15 App Router | Connects to Gateway `:8080` | HPA `2–10` pods |
| `fiverr-api-gateway` | `8080` | Spring Cloud Gateway | Redis Rate Limiter | HPA `2–8` pods |
| `fiverr-auth-service` | `8081` | Spring Boot 3 DDD | PostgreSQL (`fiverr_auth`) | HPA `2–6` pods |
| `fiverr-user-service` | `8082` | Spring Boot 3 DDD | PostgreSQL (`fiverr_user`) | HPA `2–6` pods |
| `fiverr-gig-service` | `8083` | Spring Boot 3 DDD | PostgreSQL (`fiverr_gig`) + Redis | HPA `2–8` pods |
| `fiverr-order-service` | `8084` | Spring Boot 3 DDD | PostgreSQL (`fiverr_order`) + Kafka | HPA `2–8` pods |
| `fiverr-payment-service` | `8085` | Spring Boot 3 DDD | PostgreSQL (`fiverr_payment`) + Kafka | HPA `2–8` pods |
| `fiverr-messaging-service` | `8086` | Spring Boot 3 DDD | PostgreSQL (`fiverr_messaging`) + Redis | HPA `2–6` pods |
| `fiverr-review-service` | `8087` | Spring Boot 3 DDD | PostgreSQL (`fiverr_review`) + Kafka | HPA `2–6` pods |
| `fiverr-notification-service` | `8088` | Spring Boot 3 DDD | PostgreSQL (`fiverr_notification`) + Kafka | HPA `2–6` pods |
| `fiverr-postgres` | `5432` | StatefulSet (`postgres:16-alpine`) | 20Gi–100Gi PVC (8 isolated DBs) | StatefulSet |
| `fiverr-redis` | `6379` | StatefulSet (`redis:7.4-alpine`) | 5Gi–20Gi PVC (AOF enabled) | StatefulSet |
| `fiverr-kafka` | `9092` | StatefulSet (`apache/kafka:3.8.0`) | 15Gi–50Gi PVC (KRaft mode) | StatefulSet |

---

## Repository Structure

```text
fiverr-k8s-infra/
├── docker-compose.yml                        # Full 13-container local stack
├── scripts/
│   ├── deploy-k8s.sh                         # One-command Kustomize or Helm deploy
│   └── init-postgres.sql                     # Initializes all 8 microservice databases
├── k8s/
│   ├── kustomization.yaml                    # kubectl apply -k k8s/
│   ├── base/
│   │   ├── 00-namespace.yaml                 # fiverr-club namespace
│   │   ├── 01-configmap.yaml                 # Shared cluster service discovery URLs
│   │   └── 02-secrets.yaml                   # DB, Redis, JWT & Stripe Escrow secrets
│   ├── stateful/
│   │   ├── postgres-statefulset.yaml         # PostgreSQL 16 + init ConfigMap + PVC
│   │   ├── redis-statefulset.yaml            # Redis 7.4 AOF + PVC
│   │   └── kafka-statefulset.yaml            # Apache Kafka 3.8 KRaft mode + PVC
│   ├── services/                             # 10 Deployments + Services + HPAs
│   │   ├── fiverr-api-gateway.yaml
│   │   ├── fiverr-auth-service.yaml
│   │   ├── fiverr-user-service.yaml
│   │   ├── fiverr-gig-service.yaml
│   │   ├── fiverr-order-service.yaml
│   │   ├── fiverr-payment-service.yaml
│   │   ├── fiverr-messaging-service.yaml
│   │   ├── fiverr-review-service.yaml
│   │   ├── fiverr-notification-service.yaml
│   │   └── fiverr-web.yaml
│   ├── ingress/
│   │   └── ingress.yaml                      # NGINX Ingress + Let's Encrypt TLS
│   ├── security/
│   │   └── network-policies.yaml             # Zero-trust NetworkPolicies
│   └── availability/
│       └── pdb.yaml                          # PodDisruptionBudgets for HA
└── helm/
    └── fiverr-ecosystem/                     # Umbrella Helm v3 Chart
        ├── Chart.yaml
        ├── values.yaml
        ├── values-prod.yaml
        └── templates/
```

---

## Deployment Commands

### Option 1: Kustomize (`kubectl apply -k`)
```bash
kubectl apply -k k8s/
```

### Option 2: Helm v3 Chart
```bash
helm upgrade --install fiverr-ecosystem ./helm/fiverr-ecosystem \
  --namespace fiverr-club \
  --create-namespace \
  -f ./helm/fiverr-ecosystem/values-prod.yaml
```

### Option 3: Local Docker Compose
```bash
docker compose up --build -d
```
