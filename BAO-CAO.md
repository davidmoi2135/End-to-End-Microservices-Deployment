# BÁO CÁO ĐỒ ÁN
## End-to-End Microservices Deployment — Triển khai hệ thống thương mại điện tử Microservices trên AWS với CI/CD & GitOps

---

## Mục lục

1. Tổng quan đề tài
2. Mục tiêu và phạm vi
3. Bộ công nghệ sử dụng
4. Kiến trúc tổng thể
5. Kiến trúc hệ thống Microservices
6. Giai đoạn 1 — Hạ tầng AWS với Terraform
7. Giai đoạn 2 — Cụm Kubernetes (k3s) và Bootstrap
8. Giai đoạn 3 — CI Pipeline (GitHub Actions)
9. Giai đoạn 4 — CD / GitOps (ArgoCD + Image Updater)
10. Quản lý cấu hình với Kustomize
11. Phân tách môi trường Dev và Production
12. Progressive Delivery — Argo Rollouts (Canary)
13. Bảo mật (Security)
14. Khả năng quan sát (Observability)
15. Networking, Ingress và TLS
16. Tự động co giãn (HPA)
17. Luồng nghiệp vụ thương mại điện tử
18. Kết quả đạt được
19. Hạn chế và hướng phát triển
20. Phụ lục — Lệnh vận hành

---

## 1. Tổng quan đề tài

Đồ án xây dựng và **tự động hóa toàn bộ vòng đời** của một hệ thống thương mại điện tử
theo kiến trúc **Microservices**, từ khâu khởi tạo hạ tầng Cloud, dựng cụm Kubernetes,
xây dựng pipeline CI/CD, cho tới triển khai liên tục theo mô hình **GitOps**.

Hệ thống mô phỏng một sàn thương mại điện tử thật với các nghiệp vụ: duyệt sản phẩm,
giỏ hàng, đặt hàng, kiểm soát tồn kho, thanh toán qua cổng **VNPay/VietQR** và gửi thông
báo. Toàn bộ được đóng gói thành container, đẩy lên Docker Hub và triển khai tự động lên
cụm Kubernetes chạy trên AWS EC2.

Điểm nhấn của đồ án không chỉ nằm ở ứng dụng, mà ở **quy trình DevOps khép kín**:
mỗi lần lập trình viên `git push`, mã nguồn sẽ tự động được build, quét bảo mật, đóng gói
image và triển khai lên đúng môi trường tương ứng mà gần như không cần thao tác tay.

---

## 2. Mục tiêu và phạm vi

### 2.1. Mục tiêu

- Tự động hóa hoàn toàn việc cấp phát hạ tầng (Infrastructure as Code).
- Dựng cụm Kubernetes production-ready trên Cloud.
- Xây dựng pipeline CI tách biệt cho từng microservice, có tích hợp quét chất lượng mã và quét lỗ hổng image.
- Triển khai liên tục (CD) theo mô hình **GitOps**: Git là nguồn chân lý duy nhất (single source of truth).
- Tách biệt rõ hai môi trường **Staging (dev)** và **Production (main)**.
- Áp dụng các kỹ thuật triển khai an toàn: canary, health probe, autoscaling, observability.

### 2.2. Phạm vi

| Hạng mục | Trong phạm vi | Ghi chú |
|---|---|---|
| Hạ tầng AWS | ✅ | EC2, VPC mặc định, ALB, Security Group |
| Cụm Kubernetes | ✅ | k3s (lightweight Kubernetes) |
| CI/CD | ✅ | GitHub Actions + ArgoCD |
| Microservices | ✅ | 10 service (9 backend + 1 frontend) |
| Thanh toán | ✅ | VNPay Sandbox + VietQR |
| Observability | ✅ | Prometheus, Grafana, Zipkin |
| DNS/Domain thật | ⚠️ Tùy chọn | Dùng được qua DNS name của ALB |

---

## 3. Bộ công nghệ sử dụng

| Lớp | Công nghệ | Vai trò trong đồ án |
|---|---|---|
| **Cloud Provider** | AWS (EC2, ALB, VPC, Security Group, ACM) | Hạ tầng vật lý ảo hóa |
| **IaC** | Terraform | Khai báo & cấp phát hạ tầng tự động |
| **Container Orchestration** | Kubernetes (**k3s** v1.30.5) | Điều phối container |
| **CI** | GitHub Actions | Build, test, quét bảo mật, push image |
| **Phân tích mã** | SonarQube | Static Application Security Testing (SAST) |
| **Quét image** | Trivy | Quét lỗ hổng OS & thư viện |
| **CD / GitOps** | ArgoCD + ArgoCD Image Updater | Đồng bộ Git → Cluster, tự cập nhật image |
| **Quản lý manifest** | Kustomize | Overlay cấu hình theo môi trường |
| **Progressive Delivery** | Argo Rollouts | Triển khai canary |
| **TLS** | cert-manager + Let's Encrypt | Tự động cấp & gia hạn chứng chỉ |
| **Ingress** | Traefik (mặc định của k3s) | Định tuyến HTTP/HTTPS |
| **Observability** | Prometheus, Grafana, Alertmanager, Zipkin | Metrics, dashboard, alert, tracing |
| **Thông báo** | Slack (CI + ArgoCD Notifications) | Cảnh báo build/deploy |
| **Backend** | Spring Boot 3, Spring Cloud, JDK 17 | Microservices |
| **Message Broker** | Apache Kafka | Giao tiếp bất đồng bộ giữa service |
| **CSDL** | MongoDB, PostgreSQL, MySQL | Lưu trữ theo từng service |
| **Identity** | Keycloak (OAuth2 / OIDC) | Xác thực & phân quyền |
| **Frontend** | React (TypeScript) | Giao diện storefront |
| **Container Registry** | Docker Hub (`hiunehihi/*`) | Lưu trữ image |

---

## 4. Kiến trúc tổng thể

```
                          ┌──────────────────────────────┐
   Lập trình viên         │        GitHub Repository       │
   git push (dev/main)──► │  - source code microservices   │
                          │  - manifest k8s (Kustomize)    │
                          │  - định nghĩa ArgoCD App        │
                          └───────────────┬────────────────┘
                                          │
                 ┌────────────────────────┼──────────────────────────┐
                 ▼                        ▼                           ▼
        ┌─────────────────┐     ┌──────────────────┐        ┌──────────────────┐
        │  GitHub Actions  │     │   Docker Hub     │        │     ArgoCD        │
        │  (CI per-service)│ ──► │ image registry   │ ◄──────│  Image Updater   │
        │  build/sonar/    │push │ hiunehihi/*      │ poll   │ (phát hiện digest)│
        │  trivy/push      │     └──────────────────┘        └────────┬─────────┘
        └─────────────────┘                                          │ commit digest về Git
                                                                     ▼
                          ┌──────────────────────────────────────────────────┐
                          │              AWS  (ap-southeast-1)                 │
                          │   ┌──────────────┐        ┌────────────────────┐  │
   Người dùng ──HTTP/S──► │   │ Application   │──────► │  k3s Cluster        │  │
                          │   │ Load Balancer │  :80   │  (1 master + 2 wkr) │  │
                          │   └──────────────┘        │  Traefik Ingress    │  │
                          │                            │  + 10 microservices │  │
                          │                            │  + Kafka/DB/Keycloak│  │
                          │                            │  + Prometheus/Grafana│ │
                          │                            └────────────────────┘  │
                          └──────────────────────────────────────────────────┘
```

Toàn bộ quy trình chia thành **4 giai đoạn** rõ rệt:

1. **Hạ tầng** — Terraform dựng EC2 + ALB + cài k3s.
2. **Build & Push** — GitHub Actions build image, đẩy lên Docker Hub.
3. **GitOps** — ArgoCD Image Updater phát hiện image mới, ghi ngược digest vào Git.
4. **Đồng bộ** — ArgoCD đồng bộ manifest từ Git về cluster.

---

## 5. Kiến trúc hệ thống Microservices

Hệ thống gồm **10 thành phần** triển khai trên namespace `spring-microservices`:

| # | Service | Cổng | CSDL / Phụ thuộc | Vai trò |
|---|---|---|---|---|
| 1 | **discovery-server** | 8761 | (Eureka) | Service Discovery |
| 2 | **api-gateway** | 8080 (NodePort 30085) | Keycloak | Cổng vào, định tuyến + xác thực JWT |
| 3 | **product-service** | 8080 | MongoDB | Quản lý sản phẩm (chạy dạng **Rollout** canary) |
| 4 | **cart-service** | 8080 | MongoDB | Giỏ hàng |
| 5 | **order-service** | 8080 | PostgreSQL + Kafka | Đặt hàng |
| 6 | **inventory-service** | 8080 | PostgreSQL + Kafka | Kiểm soát tồn kho |
| 7 | **payment-service** | 8080 | Kafka + VNPay | Thanh toán VNPay/VietQR |
| 8 | **notification-service** | (Kafka consumer) | Kafka | Gửi thông báo (không có HTTP server) |
| 9 | **admin-server** | 8080 | Eureka | Spring Boot Admin (giám sát) |
| 10 | **frontend** | 80 | api-gateway | Giao diện React |

**Đặc điểm kiến trúc:**

- **Database-per-service**: mỗi service sở hữu CSDL riêng (MongoDB cho product/cart,
  PostgreSQL riêng cho order & inventory). Không chia sẻ schema → giảm coupling.
- **Giao tiếp đồng bộ** qua API Gateway + Eureka (service discovery).
- **Giao tiếp bất đồng bộ** qua Kafka (`broker:29092`/`broker:9092`) cho luồng
  order → payment → inventory → notification.
- **Cấu hình tách khỏi mã**: mọi thông tin nhạy cảm (mật khẩu DB, VNPay secret, Eureka URL)
  đều inject qua `secretKeyRef` từ Secret `app-secrets`, không hard-code trong manifest.

---

## 6. Giai đoạn 1 — Hạ tầng AWS với Terraform

### 6.1. Tài nguyên được khai báo (`terraform/main.tf`)

- **Networking**: tái sử dụng **VPC mặc định** và các default subnet → đơn giản, tiết kiệm.
- **AMI**: Ubuntu 22.04 LTS (Canonical official).
- **SSH key**: nếu người dùng không cung cấp, Terraform tự sinh cặp khóa RSA 4096-bit và lưu `k3s-key.pem`.
- **Security Groups**:
  - `alb-sg`: mở 80/443 ra Internet.
  - `k8s-sg`: mở 22 (SSH), 6443 (kube API), 80/443 (chỉ từ ALB), 30000–32767 (NodePort), và toàn bộ traffic nội bộ giữa các node.
- **Application Load Balancer (ALB)**: phân phối HTTP/80 vào Traefik của k3s; có listener HTTPS/443 tùy chọn khi cung cấp `acm_certificate_arn`.
- **EC2 instances**: 1 master + 2 worker (`c7i-flex.large`, 2 vCPU/4GB), ổ gp3 10GB mỗi node.

### 6.2. Tự cài k3s qua `user_data`

Thay vì Kubespray/Ansible, đồ án dùng **k3s** — bản Kubernetes nhẹ. Khi EC2 khởi động,
script `user_data` tự động:

- **Master**: tải và cài `k3s server`, mở `--bind-address=0.0.0.0`, set `--tls-san` theo public/private IP.
- **Worker**: chờ master sẵn sàng (poll cổng 6443) rồi join cluster bằng `K3S_TOKEN` chung (sinh bằng `random_password`).

### 6.3. File sinh tự động

- `inventory/mycluster/hosts.yaml` — inventory cụm (render từ `templates/inventory.tmpl`).
- `terraform/get-kubeconfig.sh` — script SSH vào master lấy kubeconfig (trỏ thẳng public IP master, vì ALB tầng 7 không proxy được kube API tầng 4).

### 6.4. Outputs quan trọng (`terraform/output.tf`)

`alb_dns_name`, `kube_api_endpoint`, `master_public_ips`, `ssh_connect_cmds`, `k3s_token` (sensitive), và hướng dẫn `next_steps`.

---

## 7. Giai đoạn 2 — Cụm Kubernetes (k3s) và Bootstrap

Sau khi `terraform apply` xong và `kubectl get nodes` hoạt động, script
`scripts/bootstrap-cluster.sh` cài toàn bộ add-on theo **7 bước idempotent**:

| Bước | Nội dung |
|---|---|
| 1 | Cài **ArgoCD** (server-side apply do CRD lớn > 256KB) |
| 2 | Cài **ArgoCD Image Updater** (từ manifest `argocd-image-updater-0.16.0/`) |
| 3 | Cài **Argo Rollouts** v1.7.2 (controller canary/blue-green) |
| 4 | Cài **cert-manager** v1.15.3 (TLS / Let's Encrypt) |
| 5 | Tạo Secret `git-creds` (GitHub PAT) cho Image Updater ghi ngược Git |
| 6 | Tạo namespace ứng dụng + apply Secret thật |
| 7 | Đăng ký 2 ArgoCD Application: **production** (từ HEAD) và **dev** (từ `origin/dev`) |

Mọi bước đều an toàn khi chạy lại (dùng `kubectl apply` / `--dry-run=client` / `|| true`).

---

## 8. Giai đoạn 3 — CI Pipeline (GitHub Actions)

### 8.1. Cấu trúc

Mỗi microservice có **một workflow CI riêng** (`.github/workflows/<service>-ci.yaml`),
tổng cộng 10 file. Lợi ích: chỉ build lại service có thay đổi, không build cả monorepo.

### 8.2. Điều kiện kích hoạt (trigger)

```yaml
on:
  push:
    branches: [ "main", "dev" ]
    paths:
      - 'spring-boot-app/api-gateway/**'        # chỉ chạy khi service này đổi
      - '.github/workflows/api-gateway-ci.yaml'
```

→ Workflow chỉ chạy khi đúng thư mục service (hoặc chính file workflow) thay đổi, trên nhánh `main` hoặc `dev`.

### 8.3. Các bước của pipeline

1. **Checkout** (fetch-depth: 0 — SonarQube cần lịch sử git).
2. **Setup JDK 17** (Temurin) + cache Maven.
3. **Build**: `mvn clean verify -DskipTests -pl <service> -am`.
4. **SonarQube Scan** — phân tích chất lượng & lỗ hổng mã (chỉ chạy khi có token).
5. **Login Docker Hub**.
6. **Build Docker image** — gắn 2 tag: `<branch>` (vd `main`) và `<branch>-<sha>` (truy vết chính xác commit).
7. **Trivy scan** — quét lỗ hổng CRITICAL/HIGH của image (OS + library).
8. **Push image** lên Docker Hub.
9. **Slack notification** — báo thành công/thất bại.

### 8.4. Triết lý tag image

- Tag `<branch>` (vd `main`, `dev`) là **mutable** → trỏ tới bản mới nhất, dùng cho Image Updater.
- Tag `<branch>-<sha>` là **immutable** → truy vết & rollback chính xác về commit.

---

## 9. Giai đoạn 4 — CD / GitOps (ArgoCD + Image Updater)

### 9.1. Nguyên lý GitOps

Git là **nguồn chân lý duy nhất**. Trạng thái cluster luôn được đồng bộ về đúng những gì
khai báo trong Git. Con người **không** chạy `kubectl apply` thủ công lên production —
mọi thay đổi đều đi qua commit.

### 9.2. Vòng lặp tự động hoàn chỉnh

```
CI push image (tag :main, digest mới)
        │
        ▼
ArgoCD Image Updater (poll Docker Hub định kỳ ~2 phút)
   • update-strategy: digest  → phát hiện digest mới dưới tag :main
   • write-back-method: git:secret:argocd/git-creds
   • write-back-target: kustomization:spring-boot-app/k8s
        │  commit digest mới vào k8s/kustomization.yaml (nhánh main)
        ▼
ArgoCD Application "spring-microservices"
   • phát hiện commit mới trên Git
   • tự đồng bộ (auto-sync) → triển khai lên cluster
```

### 9.3. Hai Application

| Application | Nhánh | Path | Tag image | Sync |
|---|---|---|---|---|
| `spring-microservices` (Prod) | `main` | `spring-boot-app/k8s` | digest cố định (pin sha256) | **Tự động** (đã bật) |
| `spring-microservices-staging` | `dev` | `spring-boot-app/k8s-staging` | tag `dev` | Tự động (prune + selfHeal) |

> **Ghi chú thay đổi:** Trước đây production cố tình **tắt** auto-sync để người duyệt diff
> rồi bấm Sync. Theo yêu cầu vận hành, production đã được bật `syncPolicy.automated`
> (`prune: true`, `selfHeal: true`) để triển khai hoàn toàn tự động sau khi Image Updater
> commit digest. Đánh đổi: không còn bước review thủ công trước khi deploy lên production.

### 9.4. Tích hợp thông báo

ArgoCD Notifications gửi Slack khi `on-sync-failed`, `on-health-degraded`,
`on-sync-succeeded` — channel `deployments` (prod) và `deployments-staging` (dev).

---

## 10. Quản lý cấu hình với Kustomize

Cả hai môi trường dùng Kustomize. Khác biệt nằm ở field `images:`:

**Production (`k8s/kustomization.yaml`)** — pin theo **digest** (bất biến, an toàn):
```yaml
images:
  - name: hiunehihi/product-service
    digest: sha256:218d420be5c6...
```

**Staging (`k8s-staging/kustomization.yaml`)** — dùng **tag** `dev` (luôn lấy bản mới):
```yaml
images:
  - name: hiunehihi/product-service
    newTag: dev
```

→ Image Updater ghi ngược vào đúng field này. Đây cũng là lý do đồ án chọn Kustomize
thay vì Helm: write-back của Image Updater tích hợp **native** với Kustomization.

---

## 11. Phân tách môi trường Dev và Production

| Tiêu chí | Dev / Staging | Production |
|---|---|---|
| Nhánh Git | `dev` | `main` |
| Namespace | `spring-microservices-staging` | `spring-microservices` |
| Path manifest | `k8s-staging/` | `k8s/` |
| Image | tag `dev` (mutable) | digest sha256 (immutable) |
| Image Updater allow-tags | `regexp:^dev$` | tag `:main` |
| Auto-sync | Có | Có (đã bật) |
| Monitoring | Prometheus + Grafana | + Alertmanager + Prometheus RBAC |
| Mục đích | Kiểm thử, tích hợp | Phục vụ người dùng thật |

Cơ chế tách nhánh giúp tính năng được kiểm thử ở `dev` trước, khi ổn mới merge sang `main`.

---

## 12. Progressive Delivery — Argo Rollouts (Canary)

`product-service` được triển khai dưới dạng **Argo Rollout** thay vì Deployment thường,
áp dụng chiến lược **canary** từng bước:

```yaml
strategy:
  canary:
    steps:
      - setWeight: 25      # 25% traffic sang bản mới
      - pause: { duration: 60s }
      - setWeight: 50      # tăng lên 50%
      - pause: { duration: 60s }
      - setWeight: 100     # phát hành toàn bộ
```

→ Bản mới được đưa traffic dần (25% → 50% → 100%) với các khoảng dừng quan sát, giảm
rủi ro phát hành. Nếu có lỗi, có thể abort và rollback nhanh.

---

## 13. Bảo mật (Security)

| Lớp | Biện pháp |
|---|---|
| **Quét mã (SAST)** | SonarQube quét chất lượng & lỗ hổng mã trong CI |
| **Quét image** | Trivy quét lỗ hổng CRITICAL/HIGH (OS + thư viện) trước khi push |
| **Quản lý secret** | Mọi credential inject qua `secretKeyRef`; `secrets.yaml` bị `.gitignore`, chỉ commit `secret-example.yaml` |
| **Xác thực/Phân quyền** | Keycloak (OAuth2/OIDC), API Gateway xác thực JWT (`issuer-uri` realm `spring-boot-ms-realm`) |
| **TLS** | cert-manager + Let's Encrypt tự cấp & gia hạn cho Ingress |
| **Network** | Security Group hạn chế: 80/443 chỉ vào từ ALB; SSH có thể khóa theo CIDR |
| **GitOps credential** | PAT lưu trong Secret `git-creds`, không nằm trong mã |
| **IMDSv2** | EC2 yêu cầu `http_tokens = required` (chống SSRF metadata) |

---

## 14. Khả năng quan sát (Observability)

- **Prometheus** — thu thập metrics (có RBAC riêng ở production).
- **Grafana** — dashboard trực quan hóa.
- **Alertmanager** — cảnh báo (chỉ ở production).
- **Zipkin** — distributed tracing, theo dõi request xuyên service.
- **Spring Boot Admin (admin-server)** — giám sát sức khỏe các service qua Eureka.
- Tất cả truy cập qua Ingress: `prometheus.ecommerce-demo.com`, `grafana.ecommerce-demo.com`.

**Health probe** được cấu hình cho mọi service:
- `readinessProbe` — chỉ nhận traffic khi service sẵn sàng.
- `livenessProbe` — tự restart khi service treo.
- Riêng `notification-service` (Kafka consumer thuần, không có HTTP) dùng exec probe `kill -0 1` kiểm tra tiến trình JVM.

---

## 15. Networking, Ingress và TLS

- **Ingress controller**: Traefik (đi kèm k3s).
- **microservices-ingress**: định tuyến theo host
  - `api.ecommerce-demo.com` → `/api` tới api-gateway, `/auth` tới Keycloak.
  - `frontend.ecommerce-demo.com` → `/` tới frontend.
  - **Catch-all (không host)**: cho phép truy cập thẳng qua DNS name của ALB mà không cần domain riêng (`/api`, `/auth`, `/`).
- **TLS**: chứng chỉ tự cấp qua `cert-manager.io/cluster-issuer: letsencrypt-prod`, lưu trong Secret `microservices-tls`.
- **Đường đi request**: Internet → ALB (80/443) → Traefik (NodePort) → Service → Pod.

---

## 16. Tự động co giãn (HPA)

`hpa.yaml` định nghĩa HorizontalPodAutoscaler cho các service chịu tải cao
(api-gateway, product-service, order-service, payment-service...):

- `minReplicas: 2`, `maxReplicas: 10`.
- Co giãn theo **CPU 70%** và **Memory 80%**.

→ Hệ thống tự tăng/giảm số Pod theo tải thực tế, đảm bảo sẵn sàng và tiết kiệm tài nguyên.

---

## 17. Luồng nghiệp vụ thương mại điện tử

### 17.1. Luồng đặt hàng & kiểm soát tồn kho

```
Người dùng → Frontend → API Gateway (xác thực JWT qua Keycloak)
   → cart-service (giỏ hàng, MongoDB)
   → order-service (tạo đơn, PostgreSQL)
        │ kiểm tra tồn kho với inventory-service
        │ (CHẶN đặt hàng nếu vượt quá tồn kho)
        ▼
   → payment-service (VNPay Sandbox / VietQR)
        │ thanh toán thành công → phát event qua Kafka
        ▼
   → inventory-service (consume event → TRỪ kho)
   → notification-service (consume event → gửi thông báo)
```

### 17.2. Tích hợp thanh toán

- **payment-service** đọc `VNPAY_TMN_CODE` và `VNPAY_HASH_SECRET` từ Secret, tạo URL
  thanh toán VNPay Sandbox và mã **VietQR** để chuyển khoản nhanh.
- Sau khi thanh toán thành công, sự kiện được đẩy lên Kafka để các service khác xử lý
  bất đồng bộ → đảm bảo **eventual consistency** giữa thanh toán, kho và thông báo.

### 17.3. Đặc điểm nghiệp vụ

- **Inventory Control nghiêm ngặt**: chặn đặt vượt tồn kho, tự trừ kho sau thanh toán.
- **Hiển thị tồn kho thời gian thực** trên storefront.

---

## 18. Kết quả đạt được

- ✅ Hạ tầng AWS được tự động hóa hoàn toàn bằng Terraform (một lệnh `apply`).
- ✅ Cụm Kubernetes (k3s) production-ready: 1 master + 2 worker, ALB, autoscaling.
- ✅ CI tách biệt cho 10 service, tích hợp SonarQube + Trivy + Slack.
- ✅ CD theo GitOps: push code → tự build → tự cập nhật digest → tự deploy.
- ✅ Tách biệt môi trường dev/prod rõ ràng theo nhánh Git.
- ✅ Triển khai an toàn: canary, health probe, HPA, TLS, observability.
- ✅ Luồng thương mại điện tử hoàn chỉnh với kiểm soát kho và thanh toán VNPay/VietQR.

---

## 19. Hạn chế và hướng phát triển

### 19.1. Hạn chế

- Auto-sync production bật `prune: true` → có rủi ro xóa nhầm tài nguyên nếu Git sai.
- CSDL (Postgres/Mongo/Kafka/Keycloak) đang viết manifest tay, chưa dùng chart chính thức (chấp nhận được cho mục tiêu học tập, nhưng chưa "production-grade" tuyệt đối).
- Cụm dùng VPC mặc định, SSH mở `0.0.0.0/0` theo mặc định biến (nên khóa theo IP).
- Image Updater poll định kỳ → có độ trễ ~2 phút giữa CI xong và deploy.
- Chưa có backup/disaster-recovery tự động cho dữ liệu.

### 19.2. Hướng phát triển

- Bổ sung **kiểm thử tự động** (unit/integration) chạy trong CI trước khi build image.
- Cân nhắc `prune: false` cho production để giảm rủi ro, hoặc thêm Sync Window/manual gate.
- Dùng **External Secrets / Vault** thay cho Secret thủ công.
- Bổ sung **backup tự động** (Velero) cho cluster và PV.
- Thêm **service mesh** (Istio/Linkerd) cho mTLS và traffic management nâng cao.
- Mở rộng canary có **phân tích metric tự động** (AnalysisTemplate) để auto-rollback.

---

## 20. Phụ lục — Lệnh vận hành

```bash
# 1) Dựng hạ tầng
cd terraform && terraform init && terraform apply -auto-approve
./get-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes -o wide

# 2) Bootstrap cluster (ArgoCD, Image Updater, Rollouts, cert-manager...)
cd .. && export KUBECONFIG=terraform/kubeconfig
./scripts/bootstrap-cluster.sh

# 3) Build & push image thủ công (nếu cần)
cd spring-boot-app
DOCKER_USERNAME=hiunehihi IMAGE_TAG=main ./build-and-push.sh

# 4) Đăng ký ArgoCD Application
kubectl apply -f argocd/production-app.yaml      # production (main)
git show origin/dev:argocd/dev-app.yaml | kubectl apply -f -   # staging (dev)

# 5) Lấy mật khẩu ArgoCD & mở UI
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8080:443

# 6) Truy cập ứng dụng qua ALB
terraform -chdir=terraform output -raw alb_dns_name
```

---

*Báo cáo được tổng hợp từ mã nguồn thực tế của dự án: Terraform, GitHub Actions workflows,
ArgoCD Applications, Kustomize manifests, scripts bootstrap và mã nguồn các microservice.*
