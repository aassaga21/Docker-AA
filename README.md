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
12. [Docker Swarm](#10-docker-swarm-cluster-multi-nœuds)
13. [Pipeline CI/CD](#11-pipeline-cicd--github-actions)
14. [Autres cas d'usage Docker](#12-autres-cas-dusage-réalisés-avec-docker)
15. [Conclusion](#conclusion)

---

## Introduction

Ce document retrace l'ensemble des étapes réalisées pour déployer une infrastructure cloud complète et fonctionnelle sur **Infomaniak Public Cloud**. Il constitue une référence technique permettant de comprendre, reproduire ou maintenir l'environnement mis en place.

### Contexte du projet

Le projet **GIT Lab Cloud** a pour objectif de fournir une plateforme backend moderne, conteneurisée et observable, déployée sur une VM Ubuntu dans le cloud Infomaniak.

L'ensemble de l'infrastructure est défini sous forme de code (**Infrastructure as Code**) grâce à **Terraform** et **Ansible**, garantissant une installation reproductible et versionnée dans Git.

### Périmètre technique

L'infrastructure déployée couvre les couches suivantes :

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
# Installation via winget
winget install Hashicorp.Terraform

# Vérification
terraform version
```

### 2.3 Création du dossier de projet

```bash
mkdir C:\git-lab-cloud
cd C:\git-lab-cloud
```

### 2.4 Installation de nano (éditeur de texte)

```bash
winget install GNU.nano
nano --version
```

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

# Réseau privé
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

# Routeur avec accès Internet
resource "openstack_networking_router_v2" "main_router" {
  name                = "router-gitlabcloud"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "main_router_iface" {
  router_id = openstack_networking_router_v2.main_router.id
  subnet_id = openstack_networking_subnet_v2.main_subnet.id
}

# Groupe de sécurité
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

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "app_ports" {
  for_each = toset(["3000", "8000", "9090", "9100", "8080"])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_sg.id
}

# Clé SSH
resource "openstack_compute_keypair_v2" "main_key" {
  name       = "keypair-gitlabcloud"
  public_key = file(var.ssh_public_key_path)
}

# Instance VM Ubuntu 24.04
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

# IP flottante
resource "openstack_networking_floatingip_v2" "main_fip" {
  pool = "ext-floating1"
}

resource "openstack_networking_floatingip_associate_v2" "main_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.main_fip.address
  port_id     = openstack_compute_instance_v2.main_vm.network[0].port
}
```

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

### 2.6 Déploiement Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

---

## 3. Configuration initiale avec Ansible

Ansible automatise la configuration du serveur après sa création par Terraform : installation de Docker, configuration système, création des répertoires de travail.

### 3.1 Fichier d'inventaire — `inventory.ini`

```ini
[webservers]
gitlabcloud ansible_host=188.213.129.12 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[local]
localhost ansible_connection=local
```

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

    - name: Ajout du repo Docker
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
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

### 3.3 Exécution

```bash
ansible-playbook -i inventory.ini setup.yml
```

---

## 4. Déploiement de la stack Docker

### 4.1 Structure des fichiers

```
/home/ubuntu/git-lab-cloud/
├── docker-compose.yml      # Définition des services
├── nginx.conf              # Configuration reverse proxy
└── prometheus.yml          # Configuration monitoring
```

### 4.2 `docker-compose.yml` — Stack complète

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

  # ── Reverse Proxy ──────────────────────────────────────
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

  # ── Backend FastAPI ────────────────────────────────────
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

  # ── Base de données ────────────────────────────────────
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

  # ── Cache Redis ────────────────────────────────────────
  redis:
    image: redis:7-alpine
    container_name: redis
    volumes:
      - redis_data:/data
    networks:
      - app-network
    restart: unless-stopped

  # ── Monitoring ─────────────────────────────────────────
  prometheus:
    image: prom/prometheus
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
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
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
    networks:
      - app-network
    restart: unless-stopped
```

### 4.3 `nginx.conf` — Configuration Reverse Proxy

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
            proxy_pass http://fastapi;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /grafana/ {
            proxy_pass http://grafana:3000/;
        }

        location /prometheus/ {
            proxy_pass http://prometheus:9090/;
        }
    }
}
```

### 4.4 Démarrage de la stack

```bash
cd /home/ubuntu/git-lab-cloud
docker compose up -d
docker compose ps
```

---

## 5. Configuration du pare-feu

### UFW — Vérification

```bash
sudo ufw status verbose
```

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

---

## 6. Accès aux services

| Service | URL | Identifiants |
|---------|-----|-------------|
| FastAPI Docs | `http://188.213.129.12:8000/docs` | — |
| Grafana | `http://188.213.129.12:3000` | admin / admin |
| Prometheus | `http://188.213.129.12:9090` | — |
| cAdvisor | `http://188.213.129.12:8080` | — |
| Node Exporter | `http://188.213.129.12:9100/metrics` | — |

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

### 7.2 Targets Prometheus

| Job | Endpoint | Rôle |
|-----|----------|------|
| prometheus | `localhost:9090` | Auto-monitoring |
| node | `node-exporter:9100` | Métriques système VM |
| cadvisor | `cadvisor:8080` | Métriques conteneurs |
| fastapi | `api:80/metrics` | Métriques applicatives |

### 7.3 Dashboards Grafana recommandés

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Node Exporter Full | `1860` | Métriques système complètes |
| Docker & system monitoring | `893` | Conteneurs Docker |
| cAdvisor | `14282` | Métriques cAdvisor |

---

## 8. Commandes Docker utiles

### Gestion des conteneurs

```bash
# Lister les conteneurs actifs
docker ps

# Voir les logs en temps réel
docker logs <nom_conteneur> -f

# Entrer dans un conteneur
docker exec -it <nom_conteneur> bash

# Statistiques de ressources
docker stats

# Inspecter un conteneur
docker inspect <nom_conteneur>
```

### Docker Compose

```bash
# Démarrer la stack
docker compose up -d

# Arrêter la stack
docker compose down

# Redémarrer un service
docker compose restart <service>

# Voir les logs de tous les services
docker compose logs -f

# Voir l'état des services
docker compose ps

# Reconstruire les images
docker compose build --no-cache
```

### Nettoyage

```bash
# Supprimer les conteneurs arrêtés
docker container prune

# Supprimer les images non utilisées
docker image prune -a

# Nettoyage complet
docker system prune -a --volumes
```

---

## 9. Architecture du stack

```
Internet
    │
    │ IP publique : 188.213.129.12
    ▼
┌─────────────────────────────────┐
│     Security Group Infomaniak   │
│  (SSH 22, HTTP 80, HTTPS 443,   │
│   3000, 8000, 9090, 9100, 8080) │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│         UFW Firewall            │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│      Nginx (Reverse Proxy)      │
│           Port 80/443           │
└───────┬───────────────┬─────────┘
        │               │
┌───────▼──────┐ ┌──────▼───────┐
│   FastAPI    │ │   Grafana    │
│   Port 8000  │ │   Port 3000  │
└───────┬──────┘ └──────┬───────┘
        │               │
┌───────▼──────┐ ┌──────▼───────┐
│  PostgreSQL  │ │  Prometheus  │
│  Port 5432   │ │   Port 9090  │
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

## 10. Docker Swarm (Cluster multi-nœuds)

Docker Swarm permet de distribuer les conteneurs sur plusieurs nœuds pour la haute disponibilité et la scalabilité.

### 10.1 Initialisation du Manager

```bash
# Sur le nœud manager
docker swarm init --advertise-addr 188.213.129.12

# Récupérer le token worker
docker swarm join-token worker
```

### 10.2 Rejoindre le cluster (Worker)

```bash
# Sur chaque nœud worker
docker swarm join --token SWMTKN-1-xxx-yyy 188.213.129.12:2377
```

### 10.3 Déploiement d'un service en Swarm

```bash
# Déployer la stack
docker stack deploy -c docker-compose.yml gitlabcloud

# Lister les services
docker service ls

# Scaler un service
docker service scale gitlabcloud_api=3

# Voir les tâches d'un service
docker service ps gitlabcloud_api

# Supprimer la stack
docker stack rm gitlabcloud
```

### 10.4 Vérification du cluster

```bash
# Lister les nœuds
docker node ls

# Inspecter un nœud
docker node inspect <node_id>

# Promouvoir un worker en manager
docker node promote <node_id>
```

---

## 11. Pipeline CI/CD — GitHub Actions

Le pipeline CI/CD automatise la validation, les tests et le déploiement à chaque push sur la branche `main`.

### `.github/workflows/deploy.yml`

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

  # ── Validation ──────────────────────────────────────────
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

  # ── Tests ───────────────────────────────────────────────
  test:
    name: Tests applicatifs
    runs-on: ubuntu-latest
    needs: validate

    steps:
      - uses: actions/checkout@v4

      - name: Démarrer la stack de test
        run: docker compose up -d --wait

      - name: Test santé FastAPI
        run: |
          sleep 10
          curl -f http://localhost:8000/health || exit 1

      - name: Test santé Prometheus
        run: curl -f http://localhost:9090/-/healthy || exit 1

      - name: Arrêt de la stack de test
        run: docker compose down

  # ── Déploiement ─────────────────────────────────────────
  deploy:
    name: Déploiement en production
    runs-on: ubuntu-latest
    needs: test
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

### Secrets GitHub à configurer

```
Settings → Secrets and variables → Actions → New repository secret

SSH_PRIVATE_KEY   → Clé privée SSH (~/.ssh/id_rsa)
```

---

## 12. Autres cas d'usage réalisés avec Docker

### 12.1 Base de données PostgreSQL standalone

```bash
docker run -d \
  --name postgres-dev \
  -e POSTGRES_USER=dev \
  -e POSTGRES_PASSWORD=devpass \
  -e POSTGRES_DB=devdb \
  -p 5432:5432 \
  -v postgres_dev_data:/var/lib/postgresql/data \
  postgres:16-alpine
```

### 12.2 Redis avec persistance

```bash
docker run -d \
  --name redis-dev \
  -p 6379:6379 \
  -v redis_dev_data:/data \
  redis:7-alpine redis-server --appendonly yes
```

### 12.3 Adminer (interface graphique PostgreSQL)

```bash
docker run -d \
  --name adminer \
  -p 8081:8080 \
  --link postgres-dev:db \
  adminer
# Accès : http://188.213.129.12:8081
```

---

## Conclusion

L'infrastructure **GIT Lab Cloud** est entièrement déployée et opérationnelle sur Infomaniak Public Cloud. Ce projet démontre la mise en place d'une stack complète et moderne alliant Infrastructure as Code, conteneurisation, monitoring et automatisation CI/CD.

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

### Points forts

- **Infrastructure as Code** : reproductible et versionné dans Git
- **Monitoring complet** : métriques système, conteneurs et applicatives
- **Sécurité multicouche** : Security Group Infomaniak + UFW
- **Haute disponibilité** : Docker Swarm multi-nœuds
- **Déploiement continu** : pipeline GitHub Actions automatisé

### Prochaines étapes

1. Configurer **HTTPS** avec Let's Encrypt (Certbot)
2. Ajouter un **domaine DNS** personnalisé
3. Déployer le **code FastAPI métier** complet
4. Configurer des **alertes Grafana** (email, Slack)
5. Mettre en place des **sauvegardes automatiques** PostgreSQL
6. Implémenter un **reverse proxy HTTPS** avec Traefik

---

*Documentation rédigée le 11.05.2026 par Alexandra ASSAGA*