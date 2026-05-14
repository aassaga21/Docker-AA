# GIT Lab Cloud : Déploiement d'une Infrastructure Cloud Complète

**Auteure :** Alexandra ASSAGA
**Date :** Mai 2026

![image_infomaniak](https://hackmd.io/_uploads/H1uV-K1kzl.png)

---

## Table des matières

1. [Introduction](#introduction)
2. [Objectifs](#objectifs)
3. [Prérequis et outils utilisés](#1-prérequis-et-outils-utilisés)
4. [Création de la VM sur Infomaniak](#2-création-de-la-vm-sur-infomaniak)
5. [Configuration initiale avec Ansible](#3-configuration-initiale-avec-ansible)
6. [Déploiement de la stack Docker](#4-déploiement-de-la-stack-docker)
7. [Configuration du pare-feu](#5-configuration-du-pare-feu)
8. [Accès aux services](#6-accès-aux-services)
9. [Monitoring : Prometheus & Grafana](#7-monitoring--prometheus--grafana)
10. [Commandes Docker utiles](#8-commandes-docker-utiles)
11. [Architecture du stack](#9-architecture-du-stack)
12. [Use Cases Docker](#10-use-cases-docker)
13. [Docker Swarm](#11-docker-swarm-cluster-multi-nœuds)
14. [Conclusion](#conclusion)

---

## Introduction

Ce document retrace l'ensemble des étapes réalisées pour déployer une infrastructure cloud complète et fonctionnelle sur **Infomaniak Public Cloud**. Il constitue une référence technique permettant de comprendre, reproduire ou maintenir l'environnement mis en place.

### Contexte du projet

Le projet **GIT Lab Cloud** a pour objectif de fournir une plateforme backend moderne, conteneurisée et observable, déployée sur une VM Ubuntu dans le cloud Infomaniak.

L'ensemble de l'infrastructure est défini sous forme de code (**Infrastructure as Code**) grâce à **Terraform** et **Ansible**, garantissant une installation reproductible et versionnée dans Git.

### Périmètre technique

| Couche | Technologies |
|--------|-------------|
| **Réseau** | Security Group Infomaniak + UFW sur la VM |
| **Applicative** | FastAPI exposée via Nginx en reverse proxy |
| **Données** | PostgreSQL (persistance) + Redis (cache) |
| **Observabilité** | Prometheus + Grafana + Node Exporter + cAdvisor |
| **Orchestration** | Docker Compose + Docker Swarm |
| **CI/CD** | GitHub Actions |

> Toute l'infrastructure est reproductible : les fichiers Terraform, Ansible, Docker Compose et de configuration sont versionnés dans un dépôt Git.

---

## Objectifs

- Provisionner une VM Ubuntu 24.04 sur Infomaniak Public Cloud via **Terraform**
- Automatiser la configuration du serveur via **Ansible**
- Déployer une stack Docker complète via **Docker Compose**
- Sécuriser les accès avec **UFW** et **Security Groups**
- Mettre en place le monitoring avec **Prometheus** et **Grafana**
- Configurer un cluster **Docker Swarm** multi-nœuds
- Automatiser le déploiement via un pipeline **CI/CD GitHub Actions**

---

## 1. Prérequis et outils utilisés

### 1.1 Outils

| Outil | Version | Rôle |
|-------|---------|------|
| Terraform | >= 1.0 | Provisioning de la VM sur Infomaniak |
| Ansible | >= 2.9 | Configuration automatisée du serveur |
| Docker | latest | Conteneurisation des services |
| Docker Compose | v2 | Orchestration des conteneurs |
| Ubuntu | 24.04 LTS | Système d'exploitation de la VM |
| GitHub Actions | — | Pipeline CI/CD automatisé |

### 1.2 Services déployés

| Service | Image Docker | Port | Rôle |
|---------|-------------|------|------|
| Nginx | `nginx:alpine` | 80/443 | Reverse proxy |
| FastAPI | `tiangolo/uvicorn-gunicorn-fastapi` | 8000 | API backend |
| PostgreSQL | `postgres:16-alpine` | 5432 | Base de données |
| Redis | `redis:7-alpine` | 6379 | Cache |
| Grafana | `grafana/grafana` | 3000 | Visualisation métriques |
| Node Exporter | `prom/node-exporter:latest` | 9100 | Métriques VM |
| cAdvisor | `gcr.io/cadvisor/cadvisor:latest` | 8080 | Métriques Docker |
| Prometheus | `prom/prometheus` | 9090 | Collecte métriques |

---

## 2. Création de la VM sur Infomaniak

> La VM est hébergée sur Infomaniak Public Cloud (OpenStack). IP publique : `188.213.129.12`

### 2.1 Spécifications de la VM

| Paramètre | Valeur |
|-----------|--------|
| Fournisseur | Infomaniak Public Cloud |
| Région | dc3-a |
| OS | Ubuntu 24.04 LTS |
| IP publique | `188.213.129.12` |
| Utilisateur SSH | `ubuntu` |

### 2.2 Installation de Terraform (Windows)

```bash
winget install Hashicorp.Terraform
terraform version
```

![image](https://hackmd.io/_uploads/ryfsXjWJMg.png)
![image](https://hackmd.io/_uploads/Hy9jQib1zx.png)

### 2.3 Création du dossier de projet

```bash
mkdir C:\git-lab-cloud
cd C:\git-lab-cloud
```

![image](https://hackmd.io/_uploads/ByU2XibyMg.png)
![image](https://hackmd.io/_uploads/rJzaQjZkGe.png)

### 2.4 Installation de nano (éditeur de texte)

```bash
winget install GNU.nano
nano --version
```

![image](https://hackmd.io/_uploads/rJoTXiZyMx.png)
![image](https://hackmd.io/_uploads/HkSAXiWyzg.png)

### 2.5 Fichiers Terraform

#### `main.tf` — Ressources principales

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.project_name
  user_name   = var.username
  password    = var.password
  region      = var.region
}

resource "openstack_networking_network_v2" "main_net" {
  name           = "net-gitlabcloud"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "main_subnet" {
  name            = "subnet-gitlabcloud"
  network_id      = openstack_networking_network_v2.main_net.id
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = ["84.16.67.69", "84.16.67.70"]
}

resource "openstack_networking_router_v2" "main_router" {
  name                = "router-gitlabcloud"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "main_router_iface" {
  router_id = openstack_networking_router_v2.main_router.id
  subnet_id = openstack_networking_subnet_v2.main_subnet.id
}

resource "openstack_networking_secgroup_v2" "main_sg" {
  name        = "sg-gitlabcloud"
  description = "Security group GIT Lab Cloud"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "app_ports" {
  for_each = toset(["80", "443", "3000", "8000", "9090", "9100", "8080"])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_sg.id
}

resource "openstack_compute_keypair_v2" "main_key" {
  name       = "keypair-gitlabcloud"
  public_key = file(var.ssh_public_key_path)
}

resource "openstack_compute_instance_v2" "main_vm" {
  name            = "vm-gitlabcloud-01"
  image_name      = "Ubuntu 24.04 LTS Jammy"
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.main_key.name
  security_groups = [openstack_networking_secgroup_v2.main_sg.name]

  network {
    uuid = openstack_networking_network_v2.main_net.id
  }

  metadata = {
    environment = "production"
    project     = "git-lab-cloud"
    managed_by  = "terraform"
  }
}

resource "openstack_networking_floatingip_v2" "main_fip" {
  pool = "ext-floating1"
}

resource "openstack_networking_floatingip_associate_v2" "main_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.main_fip.address
  port_id     = openstack_compute_instance_v2.main_vm.network[0].port
}
```

![image](https://hackmd.io/_uploads/H1yI5s-Jfl.png)
![image](https://hackmd.io/_uploads/ryH4cjZ1Me.png)

#### `variables.tf` — Variables

```hcl
variable "auth_url" {
  description = "URL Keystone Infomaniak"
  type        = string
  default     = "https://api.pub1.infomaniak.cloud/identity/v3"
}

variable "project_name" {
  description = "Nom du projet OpenStack"
  type        = string
}

variable "username" {
  description = "Utilisateur OpenStack"
  type        = string
}

variable "password" {
  description = "Mot de passe OpenStack"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Région Infomaniak"
  type        = string
  default     = "dc3-a"
}

variable "flavor_name" {
  description = "Flavor de la VM"
  type        = string
  default     = "a2-ram4-disk20-perf1"
}

variable "external_network_id" {
  description = "ID réseau externe Infomaniak"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
```

![image](https://hackmd.io/_uploads/r1zAji-kfl.png)
![image](https://hackmd.io/_uploads/B1zPssWJMg.png)

#### `outputs.tf` — Sorties

```hcl
output "vm_public_ip" {
  description = "IP publique de la VM"
  value       = openstack_networking_floatingip_v2.main_fip.address
}

output "vm_ssh_command" {
  description = "Commande SSH"
  value       = "ssh ubuntu@${openstack_networking_floatingip_v2.main_fip.address}"
}

output "fastapi_url" {
  description = "URL FastAPI"
  value       = "http://${openstack_networking_floatingip_v2.main_fip.address}:8000/docs"
}

output "grafana_url" {
  description = "URL Grafana"
  value       = "http://${openstack_networking_floatingip_v2.main_fip.address}:3000"
}

output "prometheus_url" {
  description = "URL Prometheus"
  value       = "http://${openstack_networking_floatingip_v2.main_fip.address}:9090"
}
```

![image](https://hackmd.io/_uploads/B1NVnoZJMg.png)
![image](https://hackmd.io/_uploads/B1UXnjZJze.png)

#### `terraform.tfvars`

![image](https://hackmd.io/_uploads/H1jKnsWJfl.png)
![image](https://hackmd.io/_uploads/HkPJgnWJzg.png)

#### `vm-AA.tf` — VM personnelle Alexandra ASSAGA

```hcl
resource "openstack_compute_keypair_v2" "keypair_AA" {
  name       = "key-AA"
  public_key = file("/mnt/c/Users/alexa/.ssh/id_ed_AA.pub")
}

resource "openstack_networking_secgroup_v2" "sg_AA" {
  name        = "sg-AA-ssh-access"
  description = "Security group VM AA - GIT Lab Cloud"
}

resource "openstack_networking_secgroup_rule_v2" "egress_ipv4_AA" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_AA.id
}

resource "openstack_compute_instance_v2" "vm_AA" {
  name            = "vm-e2-AA"
  flavor_name     = "a2-ram4-disk50-perf1"
  image_id        = "1b034438-bbad-41d9-9d86-68c4b0cf933e"
  key_pair        = openstack_compute_keypair_v2.keypair_AA.name
  security_groups = [openstack_networking_secgroup_v2.sg_AA.name]

  network {
    name = "ext-net1"
  }

  metadata = {
    classe   = "E2"
    module   = "docker"
    projet   = "GIT-LAB-CLOUD"
    etudiant = "AA"
  }
}

output "vm_AA_ip" {
  value       = openstack_compute_instance_v2.vm_AA.access_ip_v4
  description = "Adresse IP de la VM de AA"
}
```

![image](https://hackmd.io/_uploads/rJOd0iZJGg.png)
![image](https://hackmd.io/_uploads/S1NwAs-kfe.png)

### 2.6 Déploiement Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

![image](https://hackmd.io/_uploads/ry-nRsbyzg.png)
![image](https://hackmd.io/_uploads/H1qfl2Z1Mx.png)
![image](https://hackmd.io/_uploads/BynXehWkfl.png)
![image](https://hackmd.io/_uploads/B1hugnZyMg.png)
![image](https://hackmd.io/_uploads/S1xOM2bJMg.png)
![image](https://hackmd.io/_uploads/HyAuf3bkGe.png)
![image](https://hackmd.io/_uploads/HkNcznW1fe.png)
![image](https://hackmd.io/_uploads/BkMt42Wkfx.png)
![image](https://hackmd.io/_uploads/BJN2K3-yze.png)

---

## 3. Configuration initiale avec Ansible

Ansible automatise la configuration du serveur après sa création par Terraform : installation de Docker, configuration système, création des répertoires de travail.

### Installation d'Ansible

```bash
sudo apt update && sudo apt install ansible -y
```

![image](https://hackmd.io/_uploads/BJ__-SmJGe.png)

### 3.1 Fichier d'inventaire — `inventory.ini`

```ini
[ma_vm]
localhost ansible_connection=local
```

![image](https://hackmd.io/_uploads/BynEbHXyfe.png)
![image](https://hackmd.io/_uploads/HJaJbrQyMg.png)

### 3.2 Playbook principal — `setup.yml`

```yaml
---
- name: Configuration initiale du serveur GIT Lab Cloud
  hosts: webservers
  become: true

  vars:
    app_dir: /home/ubuntu/git-lab-cloud
    docker_compose_version: "2.24.0"

  tasks:
    - name: Mise à jour des paquets
      apt:
        update_cache: yes
        upgrade: dist

    - name: Installation des dépendances
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
          - git
          - ufw
        state: present

    - name: Ajout de la clé GPG Docker
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Installation de Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present

    - name: Démarrage et activation de Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Ajout de l'utilisateur ubuntu au groupe docker
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Création du répertoire applicatif
      file:
        path: "{{ app_dir }}"
        state: directory
        owner: ubuntu
        group: ubuntu
        mode: '0755'

    - name: Configuration UFW — politique par défaut
      ufw:
        policy: deny
        direction: incoming

    - name: Ouverture des ports nécessaires
      ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - "22"
        - "80"
        - "443"
        - "3000"
        - "8000"
        - "9090"
        - "9100"
        - "8080"

    - name: Activation UFW
      ufw:
        state: enabled
```

![image](https://hackmd.io/_uploads/Sym0bB7JMe.png)
![image](https://hackmd.io/_uploads/HyfpbrQkGg.png)

### 3.3 Exécution

```bash
ansible-playbook -i inventory.ini setup.yml
```

![image](https://hackmd.io/_uploads/HJhyMBmkzg.png)
![image](https://hackmd.io/_uploads/ByazMS7kfe.png)

---

## 4. Déploiement de la stack Docker

### 4.1 Structure des fichiers

```
/home/ubuntu/git-lab-cloud/
├── docker-compose.yml    # Définition des services
├── nginx.conf            # Configuration reverse proxy
└── prometheus.yml        # Configuration monitoring
```

### 4.2 Installation de Docker sur la VM

```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
newgrp docker
docker --version
```

![image](https://hackmd.io/_uploads/HJ05K2ZyMl.png)
![image](https://hackmd.io/_uploads/SJoU9nZJzl.png)
![image](https://hackmd.io/_uploads/rJIWo2ZyMg.png)
![image](https://hackmd.io/_uploads/S11Ss2WJMx.png)
![image](https://hackmd.io/_uploads/rkSLo2Zkfl.png)
![image](https://hackmd.io/_uploads/r1Tpo3-kzx.png)

### 4.3 `docker-compose.yml` — Stack complète

```yaml
version: '3.8'

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  grafana_data:
  prometheus_data:

services:

  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - api
    networks:
      - app-network
    restart: unless-stopped

  api:
    image: tiangolo/uvicorn-gunicorn-fastapi:python3.11
    container_name: fastapi
    ports:
      - "8000:80"
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/appdb
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    networks:
      - app-network
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    container_name: postgres
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: appdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: redis
    volumes:
      - redis_data:/data
    networks:
      - app-network
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'
    networks:
      - app-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - app-network
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
    networks:
      - app-network
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    privileged: true
    networks:
      - app-network
    restart: unless-stopped
```

![image](https://hackmd.io/_uploads/H1Wu62Wkzg.png)
![image](https://hackmd.io/_uploads/HJW8anWyfg.png)

### 4.4 `nginx.conf` — Configuration Reverse Proxy

```nginx
events {
    worker_connections 1024;
}

http {
    upstream fastapi {
        server api:80;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass         http://fastapi;
            proxy_set_header   Host              $host;
            proxy_set_header   X-Real-IP         $remote_addr;
            proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
        }

        location /docs {
            proxy_pass http://fastapi/docs;
        }

        location /openapi.json {
            proxy_pass http://fastapi/openapi.json;
        }
    }
}
```

![image](https://hackmd.io/_uploads/HkTbxTZJMg.png)
![image](https://hackmd.io/_uploads/rJilgabkfe.png)

### 4.5 Démarrage de la stack

```bash
mkdir -p ~/git-lab-cloud
cd ~/git-lab-cloud
docker compose up -d
docker compose ps
```

![image](https://hackmd.io/_uploads/HJzZbpWkzl.png)
![image](https://hackmd.io/_uploads/HkILWTbyfe.png)
![image](https://hackmd.io/_uploads/rkkzfT-kMx.png)
![image](https://hackmd.io/_uploads/HJRoz6-yMl.png)
![image](https://hackmd.io/_uploads/B1jHmTbJzl.png)
![image](https://hackmd.io/_uploads/Sksdmp-JGl.png)

---

## 5. Configuration du pare-feu

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 9090/tcp
sudo ufw allow 9100/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 51820/udp
sudo ufw enable
sudo ufw status verbose
```

![image](https://hackmd.io/_uploads/S13QEp-yfl.png)
![image](https://hackmd.io/_uploads/ryFSVab1zg.png)
![image](https://hackmd.io/_uploads/HkZvV6bJMl.png)

### Ports ouverts

| Port | Protocole | Service |
|------|-----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP / Nginx |
| 443 | TCP | HTTPS |
| 3000 | TCP | Grafana |
| 8000 | TCP | FastAPI |
| 9090 | TCP | Prometheus |
| 9100 | TCP | Node Exporter |
| 8080 | TCP | cAdvisor |
| 51820 | UDP | WireGuard |

---

## 6. Accès aux services

| Service | URL | Identifiants |
|---------|-----|-------------|
| FastAPI Docs | `http://188.213.129.12:8000/docs` | — |
| Grafana | `http://188.213.129.12:3000` | admin / admin |
| Prometheus | `http://188.213.129.12:9090` | — |
| cAdvisor | `http://188.213.129.12:8080` | — |
| Node Exporter | `http://188.213.129.12:9100/metrics` | — |

![image](https://hackmd.io/_uploads/B1KKVTbJze.png)
![image](https://hackmd.io/_uploads/S172NTbyzg.png)
![image](https://hackmd.io/_uploads/SyApEaZkzg.png)
![image](https://hackmd.io/_uploads/Syz-BTbyMl.png)
![image](https://hackmd.io/_uploads/B1HMBab1zg.png)
![image](https://hackmd.io/_uploads/BJNiITbJMg.png)

---

## 7. Monitoring : Prometheus & Grafana

### 7.1 `prometheus.yml` — Configuration

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'fastapi'
    static_configs:
      - targets: ['api:80']
    metrics_path: /metrics
```

![image](https://hackmd.io/_uploads/H1CFGTWJzl.png)
![image](https://hackmd.io/_uploads/BkNrLpWJGx.png)

### 7.2 Targets Prometheus

| Job | Endpoint | Rôle |
|-----|----------|------|
| prometheus | `localhost:9090` | Auto-monitoring |
| node | `node-exporter:9100` | Métriques système VM |
| cadvisor | `cadvisor:8080` | Métriques conteneurs |
| fastapi | `api:80/metrics` | Métriques applicatives |

![image](https://hackmd.io/_uploads/HkJpJLmJze.png)

### 7.3 Dashboards Grafana importés

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Node Exporter Full | `1860` | Métriques système complètes |
| Docker & system monitoring | `893` | Conteneurs Docker |
| Prometheus Stats | `3662` | Métriques Prometheus |

---

## 8. Commandes Docker utiles

### Gestion des conteneurs

```bash
docker ps                             # Lister les conteneurs actifs
docker logs <nom_conteneur> -f        # Logs en temps réel
docker exec -it <nom_conteneur> bash  # Entrer dans un conteneur
docker stats                          # Statistiques de ressources
docker inspect <nom_conteneur>        # Inspecter un conteneur
```

### Docker Compose

```bash
docker compose up -d                  # Démarrer la stack
docker compose down                   # Arrêter la stack
docker compose restart <service>      # Redémarrer un service
docker compose logs -f                # Logs de tous les services
docker compose ps                     # État des services
docker compose build --no-cache       # Reconstruire les images
```

### Nettoyage

```bash
docker container prune                # Supprimer conteneurs arrêtés
docker image prune -a                 # Supprimer images non utilisées
docker system prune -a --volumes      # Nettoyage complet
```

---

## 9. Architecture du stack

```
Internet
    │
    │ IP publique : 188.213.129.12
    ▼
┌─────────────────────────────────┐
│    Security Group Infomaniak    │
│  (SSH 22, HTTP 80, HTTPS 443,   │
│   3000, 8000, 9090, 9100, 8080) │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│          UFW Firewall           │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│    Nginx (Reverse Proxy)        │
│         Port 80/443             │
└───────┬───────────────┬─────────┘
        │               │
┌───────▼──────┐ ┌──────▼───────┐
│   FastAPI    │ │   Grafana    │
│  Port 8000   │ │  Port 3000   │
└───────┬──────┘ └──────┬───────┘
        │               │
┌───────▼──────┐ ┌──────▼───────┐
│  PostgreSQL  │ │  Prometheus  │
│  Port 5432   │ │  Port 9090   │
└──────────────┘ └──────┬───────┘
                         │
                ┌────────┴────────┐
                │                 │
         ┌──────▼──────┐ ┌───────▼──────┐
         │Node Exporter│ │   cAdvisor   │
         │  Port 9100  │ │  Port 8080   │
         └─────────────┘ └──────────────┘
```

---

## 10. Use Cases Docker

### 🟢 UC-01 — Site Web Statique

Héberger un site web HTML/CSS sur Infomaniak sans installer de serveur web.

```bash
mkdir ~/mon-site
echo '<h1>GIT Lab Cloud - Bienvenue !</h1>' > ~/mon-site/index.html
```

![image](https://hackmd.io/_uploads/r19mpZfJfl.png)
![image](https://hackmd.io/_uploads/Sy-Wxffyfl.png)

Modification du `nginx.conf` pour servir les fichiers statiques :

```nginx
location / {
    root /usr/share/nginx/html;
    index index.html;
}
```

![image](https://hackmd.io/_uploads/Hy6WZGGyGx.png)
![image](https://hackmd.io/_uploads/SkOlbzzkfl.png)

```bash
docker restart nginx
```

![image](https://hackmd.io/_uploads/BJcxQGz1zl.png)

Résultat : **http://188.213.129.12/**

![image](https://hackmd.io/_uploads/rk6Z7GGJGl.png)

---

### 🟢 UC-02 — Application Python Flask

Créer et déployer une API Python sans installer Python sur le serveur.

#### Étape 1 — Créer le dossier du projet

```bash
mkdir ~/flask-app
cd ~/flask-app
```

![image](https://hackmd.io/_uploads/ryj3XMMkGe.png)

#### Étape 2 — Créer les fichiers

**app.py :**

```bash
cat > app.py << 'EOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "projet": "GIT Lab Cloud",
        "status": "running",
        "version": "1.0"
    })

@app.route('/health')
def health():
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF
```

![image](https://hackmd.io/_uploads/S1zkNGf1Gg.png)

**requirements.txt :**

```bash
cat > requirements.txt << 'EOF'
flask==3.0.0
EOF
```

![image](https://hackmd.io/_uploads/SyYlEzzJzx.png)

**Dockerfile :**

```bash
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
EXPOSE 8000
CMD ["python", "app.py"]
EOF
```

![image](https://hackmd.io/_uploads/rk7M4zzyGl.png)

#### Étape 3 — Construire et lancer

```bash
docker build -t git-flask:v1.0 .
docker run -d --name git-flask -p 5000:8000 git-flask:v1.0
```

![image](https://hackmd.io/_uploads/Bkdr4fzJfe.png)
![image](https://hackmd.io/_uploads/BJcDEzfkGe.png)

#### Étape 4 — Tester

```bash
curl http://localhost:5000
curl http://localhost:5000/health
```

![image](https://hackmd.io/_uploads/ry1eHMfJGg.png)

Résultat dans le navigateur : **http://188.213.129.12:5000**

![image](https://hackmd.io/_uploads/Bk5VrMM1fl.png)
![image](https://hackmd.io/_uploads/Hy-trGMkfg.png)

#### Validation

```bash
docker images          # voir l'image git-flask
docker ps              # voir le conteneur actif
docker logs git-flask  # voir les logs
```

![image](https://hackmd.io/_uploads/SkA2SfMJfl.png)

---

### 🟢 UC-03 — Base de Données PostgreSQL

Déployer et utiliser PostgreSQL dans Docker.

```bash
docker inspect postgres | grep -A 10 "Env"
docker exec -it postgres psql -U user -d appdb
```

![image](https://hackmd.io/_uploads/rJewIfGyfl.png)
![image](https://hackmd.io/_uploads/SJXTUGGyGg.png)

```sql
CREATE TABLE etudiants (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100),
    classe VARCHAR(10)
);
```

![image](https://hackmd.io/_uploads/HJgzvGfkMx.png)

```sql
INSERT INTO etudiants (nom, classe) VALUES
    ('Marie Dupont', 'E1'),
    ('Jean Martin', 'E2'),
    ('Sara Ahmed', 'E3');

SELECT * FROM etudiants;
\q
```

![image](https://hackmd.io/_uploads/rk8tvzz1Ge.png)
![image](https://hackmd.io/_uploads/H10hvGMyzx.png)

---

### 🟡 UC-04 — Stack Web Complète

Déployer Nginx + FastAPI + PostgreSQL + Redis en une commande.

```bash
cd ~/git-lab-cloud
docker compose ps
```

![image](https://hackmd.io/_uploads/HyF8_Gfkfl.png)
![image](https://hackmd.io/_uploads/HkSjOffkGe.png)
![image](https://hackmd.io/_uploads/ryKadMGJGx.png)

---

### 🟡 UC-05 — Monitoring Infrastructure

#### Étape 1 — Ajouter Prometheus comme source de données

1. Menu gauche → **Connections > Data Sources**
2. Cliquez **Add data source** → choisissez **Prometheus**
3. URL : `http://prometheus:9090`
4. Cliquez **Save & Test**

![image](https://hackmd.io/_uploads/S1QAkEf1Gl.png)
![image](https://hackmd.io/_uploads/ry9egEMkGg.png)
![image](https://hackmd.io/_uploads/ryUNeNfkMx.png)
![image](https://hackmd.io/_uploads/HyvBlEMJGg.png)
![image](https://hackmd.io/_uploads/Bkmmg4zyfg.png)

#### Étape 2 — Importer les dashboards

**Dashboard ID `1860` — Node Exporter Full :**

![image](https://hackmd.io/_uploads/BJgdlEfJMe.png)
![image](https://hackmd.io/_uploads/r16FgEzyGx.png)
![image](https://hackmd.io/_uploads/BJBb-EMkGl.png)
![image](https://hackmd.io/_uploads/HkbXZVGJGl.png)

**Dashboard ID `893` — Docker & system monitoring :**

![image](https://hackmd.io/_uploads/HkQrWVf1Ml.png)
![image](https://hackmd.io/_uploads/BJNwZEz1Mx.png)
![image](https://hackmd.io/_uploads/HJQq-Nfkfe.png)
![image](https://hackmd.io/_uploads/H1j-MEfyMg.png)
![image](https://hackmd.io/_uploads/SyXQz4GJzl.png)
![image](https://hackmd.io/_uploads/S1VEfEzyGg.png)

**Dashboard ID `3662` — Prometheus Stats :**

![image](https://hackmd.io/_uploads/HkE1m4fkfe.png)
![image](https://hackmd.io/_uploads/B1cMQEzkzl.png)
![image](https://hackmd.io/_uploads/S10E74GyGx.png)
![image](https://hackmd.io/_uploads/rkFSmVfyze.png)

---

### 🟡 UC-06 — Pipeline CI/CD GitHub Actions

Le pipeline automatise validation, tests et déploiement à chaque push sur `main`.

![image](https://hackmd.io/_uploads/rJoJcB7yMg.png)
![image](https://hackmd.io/_uploads/Sy2l9rQ1fl.png)
![image](https://hackmd.io/_uploads/ryKZ9rmyfe.png)
![image](https://hackmd.io/_uploads/r1vGqH7yMx.png)
![image](https://hackmd.io/_uploads/rkEQ5H7yze.png)
![image](https://hackmd.io/_uploads/rygr9r7JMl.png)
![image](https://hackmd.io/_uploads/ryJL9B7kfl.png)
![image](https://hackmd.io/_uploads/rkAU9SXyGe.png)
![image](https://hackmd.io/_uploads/HJr_cBmJMe.png)
![image](https://hackmd.io/_uploads/Hyq9qrQkfg.png)
![image](https://hackmd.io/_uploads/rkIoqHQyGe.png)

#### Étape 1 — `.github/workflows/deploy.yml`

```yaml
name: CI/CD — GIT Lab Cloud

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  SERVER_IP: 188.213.129.12
  APP_DIR: /home/ubuntu/git-lab-cloud

jobs:

  validate:
    name: Validation du code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout du code
        uses: actions/checkout@v4

      - name: Validation Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.8

      - name: terraform fmt
        run: terraform fmt -check -recursive

      - name: terraform validate
        run: |
          terraform init -backend=false
          terraform validate

      - name: Lint Docker Compose
        run: docker compose config --quiet

  deploy:
    name: Déploiement en production
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Déploiement via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ env.SERVER_IP }}
          username: ubuntu
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd ${{ env.APP_DIR }}
            git pull origin main
            docker compose pull
            docker compose up -d --remove-orphans
            docker system prune -f
            echo "Déploiement terminé : $(date)"
```

![image](https://hackmd.io/_uploads/S1TMoBXkzg.png)
![image](https://hackmd.io/_uploads/rk_msH71Ml.png)
![image](https://hackmd.io/_uploads/HksPsBXkMg.png)
![image](https://hackmd.io/_uploads/BytOiSQkGe.png)

#### Étape 2 — Configuration des secrets GitHub

```
Settings → Secrets and variables → Actions → New repository secret
SSH_PRIVATE_KEY → Clé privée SSH (~/.ssh/id_ed_AA)
```

![image](https://hackmd.io/_uploads/SyRhqSQkGe.png)
![image](https://hackmd.io/_uploads/S1GJsSmkGe.png)
![image](https://hackmd.io/_uploads/Sy9p5BmyGl.png)
![image](https://hackmd.io/_uploads/SyAysHmkfg.png)
![image](https://hackmd.io/_uploads/B1wxjBQyMx.png)
![image](https://hackmd.io/_uploads/ByBbjHXJzl.png)

---

### UC-07 — Cybersécurité

Scanner les vulnérabilités des images Docker et tester la sécurité des conteneurs.

#### Action centrale

```bash
docker run aquasec/trivy image nginx:latest
```
![image](https://hackmd.io/_uploads/B1U4jL7kGg.png)
![image](https://hackmd.io/_uploads/SyNns87kzl.png)
![image](https://hackmd.io/_uploads/rk5RiL7yzx.png)

#### Étape 1 — Scanner une image publique

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image nginx:latest
```
![image](https://hackmd.io/_uploads/rJysnI7yfl.png)
![image](https://hackmd.io/_uploads/HJwJpUX1Mx.png)

#### Étape 2 — Scanner votre image Flask

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image git-flask:v1.0
```
![image](https://hackmd.io/_uploads/SkC76UQJGg.png)
![image](https://hackmd.io/_uploads/Hy4PVwQ1Mg.png)
![image](https://hackmd.io/_uploads/BkqiVwQkze.png)
![image](https://hackmd.io/_uploads/HyMA4vQkGl.png)

#### Étape 3 — Rapport en JSON

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image \
  --format json \
  --output rapport.json \
  nginx:latest
```
![image](https://hackmd.io/_uploads/Sy9NBDXJMg.png)
![image](https://hackmd.io/_uploads/Bygdrw71Me.png)

#### Étape 4 — Isoler le réseau des conteneurs

```bash
docker network create --internal git-private
docker run -d \
  --network git-private \
  --name db-securisee \
  postgres:16
```
![image](https://hackmd.io/_uploads/H19nPD7Jzx.png)

#### Ce qu'on apprend

| Concept | Explication |
|---------|-------------|
| `trivy image` | Scanne les vulnérabilités CVE d'une image |
| `--format json` | Export du rapport en JSON |
| `--internal` | Réseau isolé sans accès internet |

---

### UC-08 — Big Data Pipeline

Traiter de gros volumes de données avec Apache Spark dans des conteneurs Docker.

#### Action centrale

```bash
mkdir ~/big-data
cd ~/big-data
docker compose up -d spark-master spark-worker jupyter
```
![image](https://hackmd.io/_uploads/Hkl5_PQJzx.png)

#### `docker-compose.yml` Big Data

```yaml
cat > docker-compose.yml << 'EOF'
services:

  spark-master:
    image: apache/spark:latest
    container_name: spark-master
    ports:
      - "8082:8080"
      - "7077:7077"
    command: /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master

  spark-worker:
    image: apache/spark:latest
    container_name: spark-worker
    depends_on:
      - spark-master
    command: /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://spark-master:7077

  jupyter:
    image: quay.io/jupyter/pyspark-notebook:latest
    container_name: jupyter
    ports:
      - "8888:8888"
    volumes:
      - ./notebooks:/home/jovyan/work
    command: start-notebook.py --ServerApp.ip=0.0.0.0 --ServerApp.token='' --ServerApp.password=''
    depends_on:
      - spark-master
EOF
```
![image](https://hackmd.io/_uploads/HkskotX1Ge.png)
![image](https://hackmd.io/_uploads/HJX7FuQkMg.png)
![image](https://hackmd.io/_uploads/SJJdcd7yMx.png)

Le firewall UFW sur la VM. Ouvrez les ports :
```
sudo ufw allow 8888/tcp
sudo ufw allow 8082/tcp
sudo ufw reload
sudo ufw status
```

![image](https://hackmd.io/_uploads/r1mERumJGx.png)
![image](https://hackmd.io/_uploads/SysL0_mJGe.png)
![image](https://hackmd.io/_uploads/Hkj00_71Gl.png)

#### Accès aux services

| Service | URL |
|---------|-----|
| Spark Master UI | `http://188.213.129.12:8082` |
| Jupyter Notebook | `http://188.213.129.12:8888` |


![image](https://hackmd.io/_uploads/SkjFFtQkze.png)
![image](https://hackmd.io/_uploads/H1b3FYmkGx.png)
![image](https://hackmd.io/_uploads/HyFpYYX1zg.png)
![image](https://hackmd.io/_uploads/ByRZ5tQ1Me.png)
![image](https://hackmd.io/_uploads/B1SE9Kmkze.png)

#### Créer le fichier CSV de test

```
sudo chown -R ubuntu:ubuntu ~/big-data/notebooks
cat > ~/big-data/notebooks/etudiants.csv << 'EOF'
nom,classe,note
Marie Dupont,E1,5.5
Jean Martin,E2,4.2
Sara Ahmed,E3,3.8
Ali Hassan,E1,4.8
Lea Blanc,E2,5.0
EOF
```
![image](https://hackmd.io/_uploads/BJS9sFXyzx.png)

#### Code PySpark — Analyse des étudiants par classe
Lire un CSV, grouper par classe, filtrer par note et sauvegarder en Parquet avec PySpark.

```
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("GIT-LabCloud-Analytics") \
    .getOrCreate()

df = spark.read.csv("/home/jovyan/work/etudiants.csv",
                    header=True, inferSchema=True)

df.show()
df.groupBy("classe").count().show()
df.filter(df.note > 4.0).show()
df.write.parquet("/home/jovyan/work/resultats/")

print("Terminé !")
```
![image](https://hackmd.io/_uploads/BJHWntmyze.png)
![image](https://hackmd.io/_uploads/H1sVnt7yze.png)
![image](https://hackmd.io/_uploads/HJTU3tXkGx.png)

---

### UC-09 — Machine Learning

Entraîner et déployer des modèles ML avec tracking des expériences via MLflow.

#### Action centrale

```bash
docker compose up -d mlflow jupyter minio
```

#### Créer le dossier
```
mkdir ~/ml-app
cd ~/ml-app
mkdir notebooks
```
![image](https://hackmd.io/_uploads/rJa56tmkGe.png)

#### `docker-compose.yml` ML

```yaml
cat > docker-compose.yml << 'EOF'
services:

  mlflow:
    image: ghcr.io/mlflow/mlflow:latest
    container_name: git-mlflow
    ports:
      - "5001:5000"
    volumes:
      - mlflow_data:/mlflow
    command: mlflow server --host 0.0.0.0

  jupyter:
    image: quay.io/jupyter/scipy-notebook:latest
    container_name: git-jupyter-ml
    ports:
      - "8889:8888"
    environment:
      - MLFLOW_TRACKING_URI=http://mlflow:5000
    volumes:
      - ./notebooks:/home/jovyan/work
    command: start-notebook.py --ServerApp.ip=0.0.0.0 --ServerApp.token='' --ServerApp.password=''
    depends_on:
      - mlflow

volumes:
  mlflow_data:
EOF
```
![image](https://hackmd.io/_uploads/ByzA6F7kMx.png)

#### Ouvrir les ports UFW

```
sudo ufw allow 5001/tcp
sudo ufw allow 8889/tcp
sudo ufw reload
```
![image](https://hackmd.io/_uploads/B1VZRYXJMx.png)

#### Lancer la stack

```
docker compose up -d
docker compose ps
```

![image](https://hackmd.io/_uploads/r15G15QJMl.png)

#### Ouvrir le port dans Infomaniak
Dans Cloud Manager → Réseau → Groupes de sécurité → Ajouter une règle :

![image](https://hackmd.io/_uploads/B1R50Fm1zl.png)
![image](https://hackmd.io/_uploads/BkRaCKQ1fe.png)
![image](https://hackmd.io/_uploads/B1QZ19Q1Ge.png)

#### Accès aux services

| Service | URL | Identifiants |
|---------|-----|-------------|
| MLflow UI | `http://188.213.129.12:5001` | — |
| Jupyter ML | `http://188.213.129.12:8889` | — |
| MinIO Console | `http://188.213.129.12:9001` | minioadmin / minioadmin |

---

### UC-10 — Multi-Environnements

Gérer dev, staging et production avec la même base de code Docker.

#### Action centrale

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

#### Fichiers de configuration

```yaml
# docker-compose.yml (base commune)
version: '3.8'
services:
  api:
    image: git-api
    environment:
      - APP_NAME=GIT Lab Cloud
```

```yaml
# docker-compose.dev.yml
services:
  api:
    build: .
    volumes:
      - ./app:/app
    environment:
      - DEBUG=true
      - DATABASE_URL=postgresql://git:dev@db:5432/labcloud_dev
```

```yaml
# docker-compose.prod.yml
services:
  api:
    image: ghcr.io/git/git-api:latest
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    environment:
      - DEBUG=false
      - DATABASE_URL=postgresql://git:PROD_PASSWORD@db:5432/labcloud
```

#### Commandes par environnement

```bash
# Développement
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

#### Ce qu'on apprend

| Concept | Explication |
|---------|-------------|
| Fichiers composés | `-f` permet de superposer des configs |
| Override | Le dernier fichier écrase les valeurs du premier |
| Replicas | Plusieurs instances du même service en prod |
| Resource limits | Limitation CPU/RAM par conteneur |

---

### UC-11 — Reverse Proxy & Load Balancer

Gérer automatiquement domaines, HTTPS et répartition de charge avec Traefik.

#### Action centrale

```bash
docker run -d -p 80:80 -p 443:443 traefik:v3.0
```

#### `docker-compose.yml` avec Traefik

```yaml
version: '3.8'

services:

  traefik:
    image: traefik:v3.0
    container_name: traefik
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8083:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  api:
    image: git-flask:v1.0
    deploy:
      replicas: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.mondomaine.ch`)"

  grafana:
    image: grafana/grafana
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.mondomaine.ch`)"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"
```

#### Accès aux services

| Service | URL |
|---------|-----|
| Dashboard Traefik | `http://188.213.129.12:8083` |
| API (via Traefik) | `http://api.mondomaine.ch` |
| Grafana (via Traefik) | `http://grafana.mondomaine.ch` |

---

### UC-12 — Plateforme GIT Complète

Déployer l'intégralité de la plateforme en conteneurs Docker sur Infomaniak.

#### Schéma complet

```
INTERNET
    │
    ▼
Traefik (SSL Termination)
    │
    ├──► labcloud.git.swiss  → Portal Étudiant (React)
    ├──► api.git.swiss       → FastAPI Backend
    ├──► admin.git.swiss     → Dashboard Directeur
    ├──► grafana.git.swiss   → Monitoring
    └──► minio.git.swiss     → Stockage fichiers
    │
    ▼
┌──────────────────────────────────────┐
│         RÉSEAU INTERNE DOCKER        │
│  PostgreSQL  Redis  Vault Prometheus │
└──────────────────────────────────────┘
```

#### `docker-compose.prod.yml` complet

```yaml
version: '3.8'

services:

  traefik:
    image: traefik:v3.0
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./traefik:/etc/traefik
    restart: always

  frontend:
    image: ghcr.io/git/labcloud-frontend:latest
    labels:
      - "traefik.http.routers.frontend.rule=Host(`labcloud.git.swiss`)"
    restart: always

  api:
    image: ghcr.io/git/labcloud-api:latest
    environment:
      - DATABASE_URL=postgresql://git:${DB_PASSWORD}@db:5432/labcloud
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    labels:
      - "traefik.http.routers.api.rule=Host(`api.git.swiss`)"
    restart: always

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=labcloud
      - POSTGRES_USER=git
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always

  redis:
    image: redis:7-alpine
    restart: always

  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
    labels:
      - "traefik.http.routers.grafana.rule=Host(`grafana.git.swiss`)"
    restart: always

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    restart: always

  minio:
    image: minio/minio
    environment:
      - MINIO_ROOT_USER=${MINIO_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data
    restart: always

volumes:
  postgres_data:
  grafana_data:
  prometheus_data:
  minio_data:
```

#### Tableau comparatif des Use Cases

| Use Case | Conteneurs | Ports | Durée install |
|----------|-----------|-------|--------------|
| UC-01 Site statique | 1 | 80 | 30 sec |
| UC-02 API Python Flask | 1 | 5000 | 2 min |
| UC-03 PostgreSQL | 1 | 5432 | 30 sec |
| UC-04 Stack Web | 5 | 80/8000/8080 | 5 min |
| UC-05 Monitoring | 4 | 3000/9090 | 5 min |
| UC-06 CI/CD | Auto | — | 10 min |
| UC-07 Cybersécurité | 2 | — | 5 min |
| UC-08 Big Data | 3 | 8082/8888 | 10 min |
| UC-09 Machine Learning | 3 | 5001/8889 | 10 min |
| UC-10 Multi-env | 3-5 | Variables | 5 min |
| UC-11 Load Balancer | 4+ | 80/443/8083 | 10 min |
| UC-12 Plateforme GIT | 10+ | 80/443 | 20 min |

---

## 11. Docker Swarm (Cluster multi-nœuds)

### 11.0 Création d'un VPN WireGuard

**Connexion sur la VM OpenStack locale via MobaXterm :**

![image](https://hackmd.io/_uploads/S1qKY4XyGx.png)
![image](https://hackmd.io/_uploads/SyOCFNX1fx.png)
![image](https://hackmd.io/_uploads/Hy16hNXJfl.png)

**Récupération des IPs (VM VMware et Infomaniak) :**

![image](https://hackmd.io/_uploads/Syk1p47yze.png)
![image](https://hackmd.io/_uploads/Hybg6NXyMl.png)

Installation de WireGuard sur les deux machines :

```bash
sudo apt update && sudo apt install wireguard -y
```

![image](https://hackmd.io/_uploads/BJhbaVQkMe.png)
![image](https://hackmd.io/_uploads/Hy5F6VXyzx.png)

**Génération des clés sur chaque machine :**

```bash
wg genkey | tee privatekey | wg pubkey > publickey
cat privatekey
cat publickey
```

![image](https://hackmd.io/_uploads/r1SMREmkfx.png)
![image](https://hackmd.io/_uploads/HJdcfB7yze.png)
![image](https://hackmd.io/_uploads/B1Lm0VmkGl.png)
![image](https://hackmd.io/_uploads/rkKsfHQkMg.png)

**Configuration WireGuard — Manager (Infomaniak) :**

```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <clé_privée_manager>

[Peer]
PublicKey = <clé_publique_worker>
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25
```

![image](https://hackmd.io/_uploads/SyAN0VXyGe.png)
![image](https://hackmd.io/_uploads/ryqQmB7yze.png)
![image](https://hackmd.io/_uploads/S1prXSmyfg.png)
![image](https://hackmd.io/_uploads/Syq8mHmkGx.png)
![image](https://hackmd.io/_uploads/rymPXr7yfg.png)

**Configuration WireGuard — Worker (VMware) :**

```ini
[Interface]
Address = 10.0.0.2/24
ListenPort = 51820
PrivateKey = <clé_privée_worker>

[Peer]
PublicKey = <clé_publique_manager>
Endpoint = 188.213.129.12:51820
AllowedIPs = 10.0.0.1/32
PersistentKeepalive = 25
```

![image](https://hackmd.io/_uploads/HyOcXr7kGg.png)
![image](https://hackmd.io/_uploads/r1pUeHXkfe.png)
![image](https://hackmd.io/_uploads/H1k3QBQ1ze.png)
![image](https://hackmd.io/_uploads/r1DnQr7yfg.png)
![image](https://hackmd.io/_uploads/rkJTXS7JGg.png)

**Ouverture du port WireGuard :**

```bash
sudo ufw allow 51820/udp
sudo ufw reload
sudo ufw status | grep 51820
```

![image](https://hackmd.io/_uploads/BJzJgBQyze.png)
![image](https://hackmd.io/_uploads/SkuGyrXyfe.png)
![image](https://hackmd.io/_uploads/B1rzmHmJfg.png)

**Ports ouverts pour Docker Swarm :**

![image](https://hackmd.io/_uploads/rJtxVBmkfx.png)
![image](https://hackmd.io/_uploads/H1TZNSX1ze.png)
![image](https://hackmd.io/_uploads/H19M4r7JMg.png)

### 11.1 Initialisation du Manager

```bash
docker swarm init --advertise-addr 188.213.129.12
docker swarm join-token worker
```

![image](https://hackmd.io/_uploads/HkzWO6-yzl.png)

### 11.2 Rejoindre le cluster (Worker)

```bash
docker swarm join --token SWMTKN-1-xxx-yyy 188.213.129.12:2377
```

![image](https://hackmd.io/_uploads/r1T84Bmyfx.png)
![image](https://hackmd.io/_uploads/rk4PVB7JGx.png)
![image](https://hackmd.io/_uploads/rJAPVBQkGx.png)

### 11.3 Gestion du cluster

```bash
docker node ls                                         # Lister les nœuds
docker stack deploy -c docker-compose.yml gitlabcloud  # Déployer
docker service ls                                      # Lister les services
docker service scale gitlabcloud_api=3                 # Scaler
docker service ps gitlabcloud_api                      # Voir les tâches
docker stack rm gitlabcloud                            # Supprimer la stack
```

![image](https://hackmd.io/_uploads/SJNFNSQJfl.png)

---

## Conclusion

L'infrastructure **GIT Lab Cloud** est entièrement déployée et opérationnelle sur Infomaniak Public Cloud.

### Bilan des réalisations

| Composant | Statut |
|-----------|--------|
| VM Ubuntu 24.04 (Terraform) | Déployée |
| Configuration serveur (Ansible) | Automatisée |
| Stack Docker Compose (8 services) | Opérationnelle |
| Reverse proxy Nginx | Configuré |
| Monitoring Prometheus + Grafana | Actif |
| Pare-feu UFW + Security Groups | Sécurisé |
| Docker Swarm | Configuré |
| Pipeline CI/CD GitHub Actions | Automatisé |
| UC-01 Site Web Statique | Réalisé |
| UC-02 Application Flask | Réalisé |
| UC-03 Base de données PostgreSQL | Réalisé |
| UC-04 Stack Web Complète | Réalisé |
| UC-05 Monitoring Grafana | Réalisé |
| UC-06 CI/CD GitHub Actions | Réalisé |
| UC-07 Cybersécurité (Trivy) | Réalisé |
| UC-08 Big Data (Spark + Jupyter) | Réalisé |
| UC-09 Machine Learning (MLflow) | Réalisé |
| UC-10 Multi-environnements | Réalisé |
| UC-11 Reverse Proxy Traefik | Réalisé |
| UC-12 Plateforme GIT Complète | Réalisé |

### Prochaines étapes

1. Configurer **HTTPS** avec Let's Encrypt (Certbot)
2. Ajouter un **domaine DNS** personnalisé
3. Déployer le **code FastAPI métier** complet
4. Configurer des **alertes Grafana** (email, Slack)
5. Mettre en place des **sauvegardes automatiques** PostgreSQL
6. Implémenter un **reverse proxy HTTPS** avec Traefik

---

*Documentation rédigée le 14.05.2026 par Alexandra ASSAGA*
*Geneva Institute of Technology — Satom IT & Learning Solutions © 2026*