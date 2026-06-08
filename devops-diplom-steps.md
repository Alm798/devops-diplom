# Дипломный проект DevOps в Yandex Cloud 2026

## Пошаговое описание выполненных работ, команд и назначения компонентов

> Проект: развёртывание инфраструктуры в Yandex Cloud, создание self-hosted Kubernetes-кластера, установка Ingress, мониторинга, тестового приложения и CI/CD через GitHub Actions + GHCR.

---

## 1. Общая архитектура проекта

Итоговая схема работы:

```text
GitHub
  ↓
GitHub Actions
  ↓
GitHub Container Registry (GHCR)
  ↓
Kubernetes Cluster
  ↓
Ingress NGINX
  ↓
Веб-приложение
```

Инфраструктурная часть:

```text
Yandex Cloud
├── Object Storage
│   └── Terraform state
├── VPC default
├── k8s-master
├── k8s-worker-1
└── k8s-worker-2
```

Используемые инструменты:

```text
Terraform
Yandex Cloud CLI
Ansible
Kubernetes
kubeadm
containerd
Flannel CNI
Helm
Ingress NGINX
Prometheus
Grafana
GitHub Actions
GitHub Container Registry
```

---

## 2. Подготовка Yandex Cloud CLI

### Проверка установленного CLI

```bash
yc version
```

Команда показывает установленную версию Yandex Cloud CLI.

Пример:

```text
Yandex Cloud CLI 1.12.0 linux/amd64
```

### Полное удаление старого yc

```bash
rm -rf ~/yandex-cloud
rm -rf ~/.config/yandex-cloud
rm -rf ~/.cache/yandex-cloud
hash -r
```

Что делают команды:

| Команда | Назначение |
|---|---|
| `rm -rf ~/yandex-cloud` | удаляет установленный бинарник и файлы yc |
| `rm -rf ~/.config/yandex-cloud` | удаляет профили, токены и настройки yc |
| `rm -rf ~/.cache/yandex-cloud` | удаляет кэш yc |
| `hash -r` | очищает кэш путей shell |

### Установка yc заново

```bash
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
exec $SHELL
yc version
```

Что делают команды:

| Команда | Назначение |
|---|---|
| `curl -sSL ...` | скачивает официальный установщик yc |
| `bash` | выполняет установочный скрипт |
| `exec $SHELL` | перезапускает текущую shell-сессию |
| `yc version` | проверяет, что CLI установлен |

---

## 3. Авторизация через сервисный аккаунт

После отключения новых OAuth-токенов в Yandex Cloud было принято решение использовать сервисный аккаунт.

### Создан сервисный аккаунт

Имя:

```text
terrafom-sa
```

Роль:

```text
admin
```

Роль `admin` была выдана на каталог, чтобы Terraform мог создавать и изменять ресурсы:

```text
Compute Cloud
VPC
Object Storage
IAM
Kubernetes
Service Accounts
```

### Создание авторизованного ключа

Ключ был сохранён на управляющей ВМ:

```text
/home/vm/keys/terraform-sa-key.json
```

### Настройка профиля yc

```bash
yc config profile create terraform
yc config profile activate terraform

yc config set service-account-key /home/vm/keys/terraform-sa-key.json
yc config set cloud-id b1gg8ijue48b000qcbuq
yc config set folder-id b1gvedmk37mbe9lcmg32
yc config set compute-default-zone ru-central1-a
```

Описание команд:

| Команда | Назначение |
|---|---|
| `yc config profile create terraform` | создаёт профиль yc с именем `terraform` |
| `yc config profile activate terraform` | активирует профиль |
| `yc config set service-account-key ...` | подключает JSON-ключ сервисного аккаунта |
| `yc config set cloud-id ...` | задаёт ID облака |
| `yc config set folder-id ...` | задаёт ID каталога |
| `yc config set compute-default-zone ...` | задаёт зону по умолчанию |

### Проверка авторизации

```bash
yc iam create-token
yc resource-manager folder get b1gvedmk37mbe9lcmg32
yc compute instance list
```

Описание:

| Команда | Назначение |
|---|---|
| `yc iam create-token` | проверяет, что сервисный аккаунт может получать IAM-токен |
| `yc resource-manager folder get ...` | проверяет доступ к каталогу |
| `yc compute instance list` | проверяет доступ к Compute Cloud |

---

## 4. Terraform backend в Object Storage

Для хранения состояния Terraform создан бакет:

```text
diplom-terraform-state-1780407281
```

### Создание static access key для S3 backend

```bash
yc iam access-key create \
  --service-account-name terrafom-sa \
  --description "terraform s3 backend key"
```

Описание ключей:

| Параметр | Назначение |
|---|---|
| `--service-account-name terrafom-sa` | указывает сервисный аккаунт |
| `--description` | описание ключа |

Команда возвращает:

```text
key_id
secret
```

`secret` показывается только один раз, поэтому его нужно сохранить.

### Сохранение переменных окружения

```bash
cat > ~/.terraform_s3_env <<'EOF'
export AWS_ACCESS_KEY_ID='YC...'
export AWS_SECRET_ACCESS_KEY='YC...'
export AWS_DEFAULT_REGION='ru-central1'
EOF
```

Описание переменных:

| Переменная | Назначение |
|---|---|
| `AWS_ACCESS_KEY_ID` | access key для Object Storage |
| `AWS_SECRET_ACCESS_KEY` | secret key для Object Storage |
| `AWS_DEFAULT_REGION` | регион Object Storage |

Подключение переменных:

```bash
source ~/.terraform_s3_env
```

### Проверка бакета

```bash
yc storage bucket list
```

---

## 5. Terraform backend.tf

Файл:

```text
infra/backend.tf
```

Содержимое:

```hcl
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }

    bucket = "diplom-terraform-state-1780407281"
    key    = "infra/terraform.tfstate"
    region = "ru-central1"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
```

Описание параметров:

| Параметр | Назначение |
|---|---|
| `backend "s3"` | указывает, что state хранится в S3-совместимом хранилище |
| `endpoints.s3` | endpoint Yandex Object Storage |
| `bucket` | имя бакета |
| `key` | путь к файлу состояния внутри бакета |
| `region` | регион |
| `skip_region_validation` | отключает AWS-валидацию региона |
| `skip_credentials_validation` | отключает AWS-проверку credentials |
| `skip_requesting_account_id` | отключает запрос AWS account ID |
| `skip_s3_checksum` | отключает проверку checksum, нужную для совместимости |

Инициализация:

```bash
terraform init
```

---

## 6. Terraform provider.tf

Файл:

```text
infra/provider.tf
```

Содержимое:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.140"
    }
  }
}

provider "yandex" {
  folder_id = "b1gvedmk37mbe9lcmg32"
  zone      = "ru-central1-a"

  service_account_key_file = "/home/vm/keys/terraform-sa-key.json"
}
```

Описание:

| Блок | Назначение |
|---|---|
| `required_version` | минимальная версия Terraform |
| `required_providers` | подключение провайдера Yandex Cloud |
| `source` | источник провайдера |
| `version` | версия провайдера |
| `folder_id` | каталог, где создаются ресурсы |
| `zone` | зона по умолчанию |
| `service_account_key_file` | путь к JSON-ключу сервисного аккаунта |

---

## 7. Использование существующей VPC

Новая VPC не создавалась из-за ограничения квоты:

```text
Quota limit vpc.networks.count exceeded
```

Поэтому была использована существующая сеть `default`.

Файл:

```text
infra/network.tf
```

```hcl
data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "subnet_a" {
  name = "default-ru-central1-a"
}

data "yandex_vpc_subnet" "subnet_b" {
  name = "default-ru-central1-b"
}

data "yandex_vpc_subnet" "subnet_d" {
  name = "default-ru-central1-d"
}
```

Описание:

| Ресурс | Назначение |
|---|---|
| `data "yandex_vpc_network"` | получает существующую сеть |
| `data "yandex_vpc_subnet"` | получает существующую подсеть |
| `default-ru-central1-a` | подсеть в зоне A |
| `default-ru-central1-b` | подсеть в зоне B |
| `default-ru-central1-d` | подсеть в зоне D |

Проверка:

```bash
terraform validate
terraform plan
```

---

## 8. Создание виртуальных машин Kubernetes

Файл:

```text
infra/k8s-vm.tf
```

Созданы:

```text
k8s-master
k8s-worker-1
k8s-worker-2
```

Параметры ВМ:

```text
2 CPU
2 GB RAM
core_fraction = 20
network-hdd = 20 GB
preemptible = true
```

Основной смысл параметров:

| Параметр | Назначение |
|---|---|
| `cores = 2` | 2 vCPU |
| `memory = 2` | 2 GB RAM |
| `core_fraction = 20` | гарантированная доля CPU 20%, дешевле |
| `preemptible = true` | прерываемая ВМ, дешевле |
| `network-hdd` | сетевой HDD-диск |
| `nat = true` | выдаёт публичный IP |
| `ssh-keys` | добавляет SSH-ключ пользователя |

Применение:

```bash
terraform plan
terraform apply
```

Подтверждение:

```text
yes
```

Проверка:

```bash
yc compute instance list
```

---

## 9. Terraform outputs

Файл:

```text
infra/outputs.tf
```

```hcl
output "k8s_master_external_ip" {
  value = yandex_compute_instance.k8s_master.network_interface[0].nat_ip_address
}

output "k8s_master_internal_ip" {
  value = yandex_compute_instance.k8s_master.network_interface[0].ip_address
}

output "k8s_worker_1_external_ip" {
  value = yandex_compute_instance.k8s_worker_1.network_interface[0].nat_ip_address
}

output "k8s_worker_1_internal_ip" {
  value = yandex_compute_instance.k8s_worker_1.network_interface[0].ip_address
}

output "k8s_worker_2_external_ip" {
  value = yandex_compute_instance.k8s_worker_2.network_interface[0].nat_ip_address
}

output "k8s_worker_2_internal_ip" {
  value = yandex_compute_instance.k8s_worker_2.network_interface[0].ip_address
}
```

Назначение:

```text
Terraform outputs используются для автоматической генерации Ansible inventory.
```

Проверка:

```bash
terraform output
```

При смене внешних IP у прерываемых ВМ выполняется:

```bash
source ~/.terraform_s3_env
terraform apply -refresh-only
terraform output
```

Описание:

| Команда | Назначение |
|---|---|
| `terraform apply -refresh-only` | обновляет Terraform state без изменения инфраструктуры |
| `terraform output` | выводит актуальные IP |

---

## 10. Ansible inventory

Файл:

```text
ansible/inventory.ini
```

Пример:

```ini
[k8s_master]
k8s-master ansible_host=158.160.50.135 ansible_user=ubuntu

[k8s_workers]
k8s-worker-1 ansible_host=51.250.2.76 ansible_user=ubuntu
k8s-worker-2 ansible_host=158.160.40.21 ansible_user=ubuntu

[k8s_cluster:children]
k8s_master
k8s_workers
```

Описание:

| Группа | Назначение |
|---|---|
| `[k8s_master]` | control-plane нода |
| `[k8s_workers]` | worker-ноды |
| `[k8s_cluster:children]` | объединённая группа всех нод |
| `ansible_host` | внешний IP ВМ |
| `ansible_user` | пользователь SSH |

### Автоматическая генерация inventory

Файл:

```text
ansible/generate-inventory.sh
```

Назначение:

```text
Скрипт берёт IP из terraform output и создаёт inventory.ini.
```

Запуск:

```bash
cd ~/diplom-devops/ansible
./generate-inventory.sh
```

Проверка:

```bash
ansible -i inventory.ini all -m ping
```

---

## 11. Подготовка нод Kubernetes через Ansible

Файл:

```text
ansible/install-k8s.yml
```

Назначение playbook:

```text
Подготовить все ВМ к установке Kubernetes.
```

Выполняемые действия:

```text
Отключение swap
Настройка kernel modules
Настройка sysctl
Установка containerd
Настройка containerd
Установка kubeadm, kubelet, kubectl
Фиксация версий Kubernetes-пакетов
```

Запуск:

```bash
ansible-playbook -i inventory.ini install-k8s.yml
```

### Основные команды внутри playbook

#### Отключение swap

```bash
swapoff -a
```

Назначение:

```text
Kubernetes требует отключённый swap.
```

#### Настройка sysctl

```text
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
```

Назначение:

| Параметр | Назначение |
|---|---|
| `bridge-nf-call-iptables` | позволяет iptables видеть bridge-трафик |
| `bridge-nf-call-ip6tables` | аналогично для IPv6 |
| `ip_forward` | включает маршрутизацию IPv4 |

#### Установка containerd

```bash
apt install containerd
```

Назначение:

```text
containerd используется как container runtime для Kubernetes.
```

#### SystemdCgroup

```text
SystemdCgroup = true
```

Назначение:

```text
Согласует управление cgroups между kubelet и containerd.
```

#### Установка Kubernetes компонентов

```bash
apt install kubelet kubeadm kubectl
```

Назначение:

| Компонент | Назначение |
|---|---|
| `kubelet` | агент Kubernetes на каждой ноде |
| `kubeadm` | инструмент инициализации кластера |
| `kubectl` | CLI для управления Kubernetes |

---

## 12. Инициализация master-ноды

Файл:

```text
ansible/init-master.yml
```

Команда:

```bash
kubeadm init --pod-network-cidr=10.244.0.0/16
```

Описание параметров:

| Параметр | Назначение |
|---|---|
| `kubeadm init` | инициализирует control-plane |
| `--pod-network-cidr=10.244.0.0/16` | CIDR для Pod-сети Flannel |

Запуск:

```bash
ansible-playbook -i inventory.ini init-master.yml
```

После инициализации копируется kubeconfig:

```text
/etc/kubernetes/admin.conf
```

в:

```text
/home/ubuntu/.kube/config
```

---

## 13. Установка Flannel CNI

Команда:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Назначение:

```text
Flannel создаёт Pod-сеть, чтобы Pod на разных нодах могли общаться друг с другом.
```

---

## 14. Подключение worker-нод

Получение join-команды:

```bash
ansible k8s_master -i inventory.ini -b -m shell -a "kubeadm token create --print-join-command"
```

Пример:

```bash
kubeadm join 10.128.0.29:6443 \
  --token p8yoks.ofm217kiamkq20dm \
  --discovery-token-ca-cert-hash sha256:...
```

Описание:

| Часть команды | Назначение |
|---|---|
| `kubeadm join` | подключает worker-ноду к кластеру |
| `10.128.0.29:6443` | внутренний IP API-сервера |
| `--token` | временный токен присоединения |
| `--discovery-token-ca-cert-hash` | проверка CA master-ноды |

Выполнение на worker-нодах:

```bash
ansible k8s_workers -i inventory.ini -b -m shell -a "kubeadm join 10.128.0.29:6443 --token ... --discovery-token-ca-cert-hash sha256:..."
```

Проверка:

```bash
ansible k8s_master -i inventory.ini -m shell -a "kubectl get nodes -o wide" -u ubuntu
```

Ожидаемый результат:

```text
k8s-master     Ready
k8s-worker-1   Ready
k8s-worker-2   Ready
```

---

## 15. Установка Helm

Файл:

```text
ansible/install-helm.yml
```

Команда внутри playbook:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Назначение:

```text
Helm используется как пакетный менеджер Kubernetes.
```

Запуск:

```bash
ansible-playbook -i inventory.ini install-helm.yml
```

Проверка:

```bash
helm version
```

---

## 16. Установка Ingress NGINX

Файл:

```text
ansible/install-ingress.yml
```

Основные команды:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

Описание:

| Команда | Назначение |
|---|---|
| `helm repo add` | добавляет Helm-репозиторий |
| `helm repo update` | обновляет список чартов |
| `helm upgrade --install` | устанавливает или обновляет релиз |
| `--namespace ingress-nginx` | namespace установки |
| `--create-namespace` | создать namespace, если его нет |

Запуск:

```bash
ansible-playbook -i inventory.ini install-ingress.yml
```

Проверка:

```bash
ansible k8s_master -i inventory.ini -m shell -a "kubectl get pods -n ingress-nginx" -u ubuntu
ansible k8s_master -i inventory.ini -m shell -a "kubectl get svc -n ingress-nginx" -u ubuntu
```

Результат:

```text
ingress-nginx-controller 1/1 Running
```

NodePort:

```text
HTTP  30591
HTTPS 31492
```

---

## 17. Установка мониторинга

Файл:

```text
ansible/install-monitoring.yml
```

Устанавливается:

```text
kube-prometheus-stack
```

Команды:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

Компоненты:

```text
Prometheus
Grafana
Alertmanager
node-exporter
kube-state-metrics
```

Проверка:

```bash
ansible k8s_master -i inventory.ini -m shell -a "kubectl get pods -n monitoring" -u ubuntu
ansible k8s_master -i inventory.ini -m shell -a "kubectl get svc -n monitoring" -u ubuntu
```

---

## 18. Тестовое приложение nginx

Файл:

```text
ansible/deploy-nginx.yml
```

Playbook создаёт:

```text
Namespace app
Deployment nginx
Service nginx-service
Ingress nginx-ingress
```

Запуск:

```bash
ansible-playbook -i inventory.ini deploy-nginx.yml
```

Проверка:

```bash
curl http://158.160.50.135:30591
```

Ingress был исправлен:

```yaml
pathType: Prefix
```

Причина:

```text
pathType: Exact пропускал только /
и не отдавал /architecture.png
```

---

## 19. Веб-приложение

Файлы:

```text
app/
├── Dockerfile
├── architecture.png
└── index.html
```

### Dockerfile

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html/
```

Описание:

| Строка | Назначение |
|---|---|
| `FROM nginx:alpine` | базовый минимальный nginx-образ |
| `COPY . /usr/share/nginx/html/` | копирует сайт в стандартную директорию nginx |

### index.html

Содержит:

```text
Название диплома
ФИО
Стек технологий
Архитектурную схему проекта
```

---

## 20. GitHub Actions CI

Файл:

```text
.github/workflows/build.yml
```

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Получение исходного кода
        uses: actions/checkout@v4

      - name: Вход в GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Сборка Docker-образа
        run: docker build -t ghcr.io/alm798/devops-diplom:latest ./app

      - name: Публикация Docker-образа
        run: docker push ghcr.io/alm798/devops-diplom:latest
```

Описание:

| Блок | Назначение |
|---|---|
| `name` | имя workflow |
| `on.push.branches.main` | запуск при push в main |
| `permissions.contents: read` | разрешение читать код |
| `permissions.packages: write` | разрешение публиковать packages |
| `runs-on: ubuntu-latest` | GitHub runner |
| `actions/checkout@v4` | скачивает код репозитория |
| `docker/login-action@v3` | логинится в GHCR |
| `github.actor` | пользователь, запустивший workflow |
| `secrets.GITHUB_TOKEN` | автоматический токен GitHub |
| `docker build` | собирает Docker image |
| `docker push` | публикует image в GHCR |

Результат:

```text
ghcr.io/alm798/devops-diplom:latest
```

---

## 21. Деплой образа из GHCR в Kubernetes

Команда:

```bash
ansible k8s_master -i inventory.ini -m shell -a \
"kubectl set image deployment/nginx nginx=ghcr.io/alm798/devops-diplom:latest -n app" \
-u ubuntu
```

Описание:

| Часть | Назначение |
|---|---|
| `kubectl set image` | меняет image у Deployment |
| `deployment/nginx` | имя Deployment |
| `nginx=...` | имя контейнера и новый image |
| `-n app` | namespace приложения |

Проверка rollout:

```bash
ansible k8s_master -i inventory.ini -m shell -a \
"kubectl rollout status deployment/nginx -n app" \
-u ubuntu
```

Проверка Pod:

```bash
ansible k8s_master -i inventory.ini -m shell -a \
"kubectl get pods -n app -o wide" \
-u ubuntu
```

Проверка содержимого контейнера:

```bash
ansible k8s_master -i inventory.ini -m shell -a \
"kubectl exec -n app deployment/nginx -- ls -la /usr/share/nginx/html/" \
-u ubuntu
```

---

## 22. Проверка приложения снаружи

Команда:

```bash
curl http://158.160.50.135:30591
```

В браузере:

```text
http://158.160.50.135:30591
```

Результат:

```text
Открывается страница:
Дипломный проект DevOps
Михеев Алексей
Архитектурная схема проекта
```

---

## 23. Работа с Git

### Добавление изменений

```bash
git add .
```

Добавляет все изменённые файлы в индекс.

### Коммит

```bash
git commit -m "Сообщение коммита"
```

Создаёт локальный коммит.

### Push

```bash
git push origin main
```

Отправляет изменения в GitHub.

### Pull rebase при конфликте с удалённым репозиторием

```bash
git pull --rebase origin main
```

Подтягивает изменения из GitHub и переносит локальные коммиты поверх них.

---

## 24. Решённые проблемы

### 1. OAuth Yandex Cloud после 01.06.2026

Проблема:

```text
OAuth token issued after 2026-06-01 is not supported
```

Решение:

```text
Использована авторизация через сервисный аккаунт и JSON key.
```

### 2. Лимит VPC

Проблема:

```text
Quota limit vpc.networks.count exceeded
```

Решение:

```text
Использована существующая сеть default через Terraform data sources.
```

### 3. Дорогой Managed Kubernetes

Проблема:

```text
Managed Kubernetes regional master показывал стоимость ~17 582 ₽/мес.
```

Решение:

```text
Managed Kubernetes удалён.
Развёрнут self-hosted Kubernetes на 3 прерываемых ВМ.
```

### 4. Смена IP у прерываемых ВМ

Проблема:

```text
Внешние IP меняются после остановки/старта ВМ.
```

Решение:

```bash
terraform apply -refresh-only
./generate-inventory.sh
```

### 5. SSH host key verification failed

Проблема:

```text
REMOTE HOST IDENTIFICATION HAS CHANGED
```

Решение:

```bash
ssh-keygen -f /home/vm/.ssh/known_hosts -R IP
ssh-keyscan -H IP >> /home/vm/.ssh/known_hosts
```

### 6. Ingress отдавал 404 для картинки

Проблема:

```yaml
pathType: Exact
```

Решение:

```yaml
pathType: Prefix
```

---

## 25. Итоговое состояние проекта

Выполнено:

```text
Yandex Cloud infrastructure
Terraform backend
Terraform IaC
Self-hosted Kubernetes
Ansible automation
Ingress NGINX
Monitoring stack
GitHub Actions CI
GHCR registry
Application deployment
External access through Ingress
```

Готовность проекта:

```text
90-92%
```

Осталось для финальной сдачи:

```text
README
Скриншоты
Описание архитектуры
Описание CI/CD
Финальный отчёт
```
