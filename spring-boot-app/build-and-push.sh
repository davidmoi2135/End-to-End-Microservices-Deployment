#!/bin/bash

# USERNAME DOCKER HUB CỦA BẠN
DOCKER_USERNAME="kaingyn615"

echo "Bắt đầu build và push images cho project Microservices (User: $DOCKER_USERNAME)..."

# Danh sách các microservices sử dụng Maven/Jib
JAVA_SERVICES=("product-service" "order-service" "inventory-service" "notification-service" "api-gateway" "discovery-server" "admin-server" "cart-service" "payment-service")

for SERVICE in "${JAVA_SERVICES[@]}"
do
    echo "--------------------------------------------------------"
    echo "Đang xử lý Java Service: $SERVICE"
    echo "--------------------------------------------------------"
    
    cd $SERVICE
    # 1. Build vào Docker local trước (tránh lỗi 401 của Jib)
    mvn compile jib:dockerBuild
    
    if [ $? -eq 0 ]; then
        # 2. Push thủ công bằng lệnh docker chuẩn
        echo "Build thành công $SERVICE local. Đang đẩy lên Docker Hub..."
        docker push $DOCKER_USERNAME/$SERVICE:latest
        if [ $? -eq 0 ]; then
            echo "Thành công: $SERVICE đã được push lên Docker Hub!"
        else
            echo "Lỗi: Không thể push $SERVICE bằng lệnh docker push."
        fi
    else
        echo "Lỗi: Không thể build $SERVICE. Vui lòng kiểm tra log biên dịch."
    fi
    cd ..
done

# Xử lý Frontend
echo "--------------------------------------------------------"
echo "Đang xử lý Frontend Service"
echo "--------------------------------------------------------"

cd frontend
docker build -t $DOCKER_USERNAME/frontend:latest .
docker push $DOCKER_USERNAME/frontend:latest

if [ $? -eq 0 ]; then
    echo "Thành công: frontend đã được push lên Docker Hub!"
else
    echo "Lỗi: Không thể build/push frontend."
fi
cd ..

echo "Tất cả các dịch vụ đã được xử lý xong!"
