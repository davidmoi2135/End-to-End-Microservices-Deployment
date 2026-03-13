# 🚀 End-to-End Microservices Deployment (Phase 1: Infrastructure & Kubernetes)

Dự án này thực hiện tự động hóa hoàn toàn quy trình xây dựng hạ tầng Cloud và khởi tạo cụm Kubernetes chuẩn Production. Đây là nền tảng (Infrastructure) vững chắc để triển khai các ứng dụng Microservices và luồng MLOps ở các giai đoạn tiếp theo.

## 🛠 Công nghệ cốt lõi
* **Cloud Provider:** AWS (Amazon Web Services).
* **IaC:** Terraform (Quản lý EC2, VPC, Security Groups).
* **Configuration Management:** Ansible & Kubespray.
* **Orchestration:** Kubernetes v1.30+ (1 Master, 2 Workers).
* **OS:** Ubuntu 22.04 LTS (Đảm bảo tương thích thư viện `glibc` cho Container Runtime).

## 🏗 Mô hình triển khai
Hạ tầng được triển khai trên 3 phân vùng EC2:
- `node1`: Master Node (Control Plane, etcd, API Server).
- `node2`: Worker Node 01.
- `node3`: Worker Node 02.

---

## 📖 Hướng dẫn triển khai (Golden Path)

### 1. Chuẩn bị môi trường
* Đã cấu hình AWS Credentials (`aws configure`).
* Đã có file SSH Key (`.pem`) trên AWS.
* Thiết lập quyền bảo mật cho file Key (trên Linux/WSL):
  ```bash
  chmod 400 ~/.ssh/trinhkeypair-ap.pem
  2. Khởi tạo hạ tầng với Terraform
Terraform sẽ tự động thiết lập mạng VPC, mở các Port bảo mật (22, 6443, 2379-2380) và sinh ra file cấu hình IP nội bộ cho Ansible.

Bash
cd terraform
terraform init
terraform apply -auto-approve
3. Cài đặt cụm Kubernetes bằng Kubespray
Do Ansible không chạy trực tiếp trên Windows, bước này cần thực hiện trên WSL hoặc môi trường Linux.

Bash
# Clone Kubespray (phiên bản ổn định)
git clone [https://github.com/kubernetes-sigs/kubespray.git](https://github.com/kubernetes-sigs/kubespray.git)
cd kubespray

# Tạo môi trường ảo Python và cài đặt thư viện
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Triển khai cụm (Sử dụng IP Private để tối ưu bảo mật nội bộ)
ansible-playbook -i ../inventory/mycluster/hosts.yaml \
                 --become --become-user=root \
                 --user ubuntu \
                 --private-key ~/.ssh/trinhkeypair-ap.pem \
                 -e "ansible_python_interpreter=/usr/bin/python3" \
                 -e "etcd_kubeadm_enabled=true" \
                 cluster.yml
4. Kết nối và Kiểm tra cụm
Sau khi Ansible hoàn tất, SSH vào Master Node để cấp quyền điều khiển cho user ubuntu:

Bash
# Truy cập Master Node
ssh -i ~/.ssh/trinhkeypair-ap.pem ubuntu@<MASTER_PUBLIC_IP>

# Cấu hình Kubeconfig cục bộ
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Kiểm tra trạng thái các Nodes
kubectl get nodes
🎯 Kết quả đạt được
[x] Hạ tầng AWS tự động hóa hoàn toàn, không cấu hình tay.

[x] Cụm Kubernetes đạt trạng thái Ready trên tất cả các node.

[x] Hệ thống mạng nội bộ etcd thông suốt thông qua IP Private của VPC.

[x] Sẵn sàng cho Phase 2: Triển khai CI/CD và Microservices.
