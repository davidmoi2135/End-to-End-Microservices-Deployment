# NỘI DUNG SLIDE THUYẾT TRÌNH
## End-to-End Microservices Deployment trên AWS với CI/CD & GitOps

> Gợi ý: mỗi mục `---` là một slide. Tổng ~23 slide. Phần "Thuyết minh" là lời nói gợi ý cho người trình bày, không in lên slide.

---

## Slide 1 — Trang bìa

# End-to-End Microservices Deployment
### Triển khai hệ thống TMĐT Microservices trên AWS với CI/CD & GitOps

- Môn học: NT548 — DevOps / Cloud
- Nhóm thực hiện: _[tên thành viên]_
- GVHD: _[tên giảng viên]_

**Thuyết minh:** Giới thiệu tên đề tài, khẳng định trọng tâm là tự động hóa toàn bộ quy trình DevOps.

---

## Slide 2 — Đặt vấn đề

- Triển khai thủ công microservices: **chậm, dễ sai, khó tái lập**.
- Nhiều service → cần build/deploy độc lập, không ảnh hưởng lẫn nhau.
- Cần tách biệt môi trường **dev** và **production**.
- Cần triển khai **an toàn** (rollback, canary) và **quan sát được**.

→ Giải pháp: **tự động hóa khép kín** từ hạ tầng đến triển khai.

---

## Slide 3 — Mục tiêu đồ án

1. Tự động hóa hạ tầng Cloud (Infrastructure as Code).
2. Dựng cụm Kubernetes production-ready.
3. CI tách biệt từng service + quét bảo mật.
4. CD theo mô hình **GitOps** (Git là nguồn chân lý).
5. Tách môi trường Dev / Production.
6. Triển khai an toàn: canary, health probe, autoscaling, observability.

---

## Slide 4 — Bộ công nghệ

| Lớp | Công nghệ |
|---|---|
| Cloud | AWS (EC2, ALB, VPC, SG) |
| IaC | Terraform |
| Orchestration | Kubernetes (k3s v1.30) |
| CI | GitHub Actions |
| Bảo mật | SonarQube + Trivy |
| CD / GitOps | ArgoCD + Image Updater |
| Manifest | Kustomize |
| Canary | Argo Rollouts |
| TLS / Ingress | cert-manager + Traefik |
| Observability | Prometheus, Grafana, Zipkin |
| Backend | Spring Boot 3, Kafka, Mongo/Postgres |
| Auth | Keycloak (OAuth2/OIDC) |
| Frontend | React (TypeScript) |

---

## Slide 5 — Kiến trúc tổng thể

```
Dev ─push─► GitHub ─► GitHub Actions ─► Docker Hub
                                            ▲
                                            │ poll
                          ArgoCD Image Updater ─commit digest─► Git
                                            │
                                            ▼ auto-sync
   Người dùng ─HTTP/S─► ALB ─► k3s Cluster (Traefik + 10 services)
```

**4 giai đoạn:** Hạ tầng → Build/Push → GitOps → Đồng bộ.

**Thuyết minh:** Nhấn mạnh vòng lặp khép kín: lập trình viên chỉ cần `git push`.

---

## Slide 6 — Kiến trúc Microservices (10 thành phần)

| Service | CSDL/Phụ thuộc | Vai trò |
|---|---|---|
| discovery-server | Eureka | Service Discovery |
| api-gateway | Keycloak | Cổng vào + JWT |
| product-service | MongoDB | Sản phẩm (Canary) |
| cart-service | MongoDB | Giỏ hàng |
| order-service | PostgreSQL + Kafka | Đặt hàng |
| inventory-service | PostgreSQL + Kafka | Tồn kho |
| payment-service | Kafka + VNPay | Thanh toán |
| notification-service | Kafka | Thông báo |
| admin-server | Eureka | Giám sát |
| frontend | api-gateway | Giao diện React |

→ **Database-per-service**, giao tiếp đồng bộ (Gateway) + bất đồng bộ (Kafka).

---

## Slide 7 — Giai đoạn 1: Hạ tầng với Terraform

- VPC mặc định + ALB + Security Groups.
- 1 master + 2 worker EC2 (Ubuntu 22.04).
- **k3s tự cài qua `user_data`** (không cần Ansible).
- Tự sinh: SSH key, kubeconfig, inventory.

```bash
cd terraform
terraform init && terraform apply -auto-approve
```

**Thuyết minh:** Một lệnh duy nhất dựng toàn bộ hạ tầng + cluster.

---

## Slide 8 — Giai đoạn 1: Mạng & bảo mật hạ tầng

- **ALB** (80/443) → Traefik của k3s.
- **k8s-sg**: chỉ mở 80/443 từ ALB, 6443 kube API, NodePort để debug.
- **IMDSv2** bắt buộc (`http_tokens = required`).
- SSH có thể khóa theo CIDR cá nhân.

Đường đi: `Internet → ALB → Traefik → Service → Pod`.

---

## Slide 9 — Giai đoạn 2: Bootstrap cluster

`scripts/bootstrap-cluster.sh` — 7 bước idempotent:

1. ArgoCD
2. ArgoCD Image Updater
3. Argo Rollouts (canary)
4. cert-manager (TLS)
5. Secret `git-creds` (PAT)
6. Namespace + Secret ứng dụng
7. Đăng ký 2 ArgoCD Application (dev + prod)

---

## Slide 10 — Giai đoạn 3: CI Pipeline

- Mỗi service **1 workflow riêng** → chỉ build service thay đổi.
- Trigger: push `main`/`dev` + lọc theo `paths`.

```yaml
on:
  push:
    branches: [ "main", "dev" ]
    paths: [ 'spring-boot-app/api-gateway/**' ]
```

---

## Slide 11 — Giai đoạn 3: Các bước CI

1. Checkout (fetch-depth 0)
2. Setup JDK 17 + cache Maven
3. **Build** (`mvn clean verify`)
4. **SonarQube** scan (chất lượng & lỗ hổng mã)
5. Login Docker Hub
6. **Build image** (tag `main` + `main-<sha>`)
7. **Trivy** quét lỗ hổng CRITICAL/HIGH
8. **Push** Docker Hub
9. **Slack** notify

---

## Slide 12 — Triết lý tag image

- `:<branch>` (vd `:main`) → **mutable**, dùng cho Image Updater.
- `:<branch>-<sha>` → **immutable**, truy vết & rollback.

→ Vừa tự động hóa, vừa truy xuất chính xác commit nào đang chạy.

---

## Slide 13 — Giai đoạn 4: GitOps là gì?

- **Git = nguồn chân lý duy nhất.**
- Trạng thái cluster luôn được kéo về đúng khai báo trong Git.
- Không `kubectl apply` thủ công lên production.
- Mọi thay đổi đều qua commit → có lịch sử, dễ audit & rollback.

---

## Slide 14 — Vòng lặp tự động hoàn chỉnh

```
CI push image (:main, digest mới)
      ▼
ArgoCD Image Updater (poll ~2 phút)
   • update-strategy: digest
   • write-back vào kustomization.yaml (nhánh main)
      ▼
ArgoCD App auto-sync → deploy lên cluster
```

**Thuyết minh:** Đây là trái tim của đồ án — hoàn toàn không cần thao tác tay.

---

## Slide 15 — Dev vs Production

| Tiêu chí | Dev | Production |
|---|---|---|
| Nhánh | `dev` | `main` |
| Namespace | ...-staging | spring-microservices |
| Image | tag `dev` | digest sha256 |
| Auto-sync | Có | **Có (đã bật)** |
| Monitoring | Prom+Grafana | + Alertmanager |

→ Tính năng kiểm thử ở `dev`, ổn rồi merge sang `main`.

---

## Slide 16 — Vì sao Kustomize (không Helm)?

- Image Updater write-back **native** vào field `images:` của Kustomization.
- Khác biệt dev/prod nhỏ → overlay là đủ.
- Manifest tường minh, dễ giải thích & chấm điểm.

```yaml
# prod: pin digest        # dev: dùng tag
digest: sha256:218d42...  newTag: dev
```

---

## Slide 17 — Progressive Delivery (Canary)

`product-service` chạy dạng **Argo Rollout**:

```yaml
canary:
  steps:
    - setWeight: 25
    - pause: 60s
    - setWeight: 50
    - pause: 60s
    - setWeight: 100
```

→ Đưa traffic dần 25→50→100%, giảm rủi ro phát hành, rollback nhanh.

---

## Slide 18 — Bảo mật

- **SAST**: SonarQube trong CI.
- **Image scan**: Trivy (CRITICAL/HIGH).
- **Secret**: `secretKeyRef`, `secrets.yaml` bị gitignore.
- **Auth**: Keycloak OAuth2/OIDC, Gateway xác thực JWT.
- **TLS**: cert-manager + Let's Encrypt tự gia hạn.
- **Network**: SG hạn chế, IMDSv2.

---

## Slide 19 — Observability

- **Prometheus** — metrics.
- **Grafana** — dashboard.
- **Alertmanager** — cảnh báo (prod).
- **Zipkin** — distributed tracing.
- **Spring Boot Admin** — giám sát service.
- **Health probe** + **HPA** (2→10 pod, CPU 70% / Mem 80%).

---

## Slide 20 — Luồng nghiệp vụ TMĐT

```
Frontend → API Gateway (JWT)
  → cart → order (kiểm tra tồn kho, CHẶN nếu vượt)
  → payment (VNPay/VietQR)
        │ thành công → Kafka event
        ▼
  → inventory (TRỪ kho)  +  notification (thông báo)
```

→ Thanh toán VNPay Sandbox + VietQR, kiểm soát kho nghiêm ngặt qua Kafka.

---

## Slide 21 — Kết quả đạt được

- ✅ Hạ tầng AWS tự động hóa hoàn toàn.
- ✅ Cụm k3s production-ready (1 master + 2 worker).
- ✅ CI cho 10 service + SonarQube + Trivy + Slack.
- ✅ CD GitOps: push code → tự deploy.
- ✅ Tách dev/prod, canary, HPA, TLS, observability.
- ✅ Luồng TMĐT hoàn chỉnh + thanh toán VNPay/VietQR.

---

## Slide 22 — Hạn chế & hướng phát triển

**Hạn chế:**
- `prune: true` ở prod → rủi ro xóa nhầm.
- CSDL viết manifest tay; Image Updater có độ trễ ~2 phút.

**Hướng phát triển:**
- Thêm test tự động trong CI.
- External Secrets / Vault; backup Velero.
- Canary có auto-analysis & auto-rollback.
- Service mesh (Istio) cho mTLS.

---

## Slide 23 — Demo & Hỏi đáp

**Demo gợi ý:**
1. `git push` lên `dev` → xem CI chạy.
2. ArgoCD UI: Application tự Synced/Healthy.
3. Truy cập storefront qua ALB DNS.
4. Đặt hàng → thanh toán VNPay → kho tự trừ.

# Cảm ơn — Q&A

**Thuyết minh:** Mở ArgoCD UI và Grafana để minh họa trực quan vòng lặp tự động.
