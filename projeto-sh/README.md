# 🚀 AWS DevOps Infrastructure - Automated & Secure

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![Bash](https://img.shields.io/badge/Bash-Script-green?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Cost](https://img.shields.io/badge/Cost-$0--17%2Fmonth-success)](README.md#-estimativa-de-custos-us-east-1)

Infraestrutura completa para **RDS PostgreSQL privado** com acesso via **Bastion Host** usando **AWS Systems Manager (SSM)**. 

✨ **Zero configuração de chaves SSH** | 🔒 **Máxima segurança** | 💰 **Controle total de custos**

---

## 📋 Pré-requisitos

- AWS CLI instalado e configurado
- Credenciais AWS com permissões para EC2, RDS, VPC, IAM
- Bash shell (Linux/Mac/WSL)

### Configurar Credenciais AWS

**Opção 1 - Profile default:**
```bash
aws configure
```

**Opção 2 - Múltiplos profiles:**
```bash
aws configure --profile meu-projeto
```

Depois edite o `.env` e defina:
```bash
AWS_PROFILE=meu-projeto
```

## 🏗️ Arquitetura

```
Internet → IGW → VPC (10.0.0.0/16)
                  ├─ Subnet Pública (10.0.1.0/24) → Bastion (t3.nano)
                  └─ Subnets Privadas (10.0.2.0/24, 10.0.3.0/24) → RDS (db.t4g.micro)
                     
Acesso: Você → SSM Session Manager → Bastion → RDS
```

## ⚙️ Configuração

**1. Copie o arquivo de exemplo:**
```bash
cp .env.example .env
```

**2. Edite o `.env` com suas configurações:**
```bash
# Credenciais AWS
AWS_PROFILE=default       # Profile do ~/.aws/credentials
AWS_REGION=us-east-1      # Região AWS

# Identificação do Projeto
PROJECT_NAME=DataApp      # Nome do seu projeto
ENV=Prod                  # Ambiente (Prod, Dev, HML)

# Configuração de Portas
LOCAL_PORT=5433           # Porta local do túnel
REMOTE_PORT=5432          # Porta do PostgreSQL

# Credenciais RDS
DB_USER=postgres          # Usuário do banco
```

⚠️ **Importante:** 
- A senha do banco será solicitada de forma segura durante o deploy
- O arquivo `.env` está no `.gitignore` (não será commitado)

## 🎯 Guia Rápido (3 Comandos Principais)

### 0️⃣ Validar Ambiente (Primeira Vez)
```bash
./validate.sh
```
Verifica AWS CLI, credenciais, permissões e dependências

### 1️⃣ Criar Infraestrutura
```bash
./deploy.sh
```
Cria TUDO: VPC, Subnets, Security Groups, IAM, Bastion e RDS (~10 min)

### 2️⃣ Conectar ao Banco
```bash
./connect.sh
```
Liga Bastion → Abre túnel → Conecte em `localhost:5433` → Desliga Bastion automaticamente

**Exemplo com psql:**
```bash
psql -h localhost -p 5433 -U postgres -d postgres
```

### 3️⃣ Destruir Tudo
```bash
./destroy.sh
```
Deleta TUDO: VPC, SGs, IAM, Bastion, RDS, **TODOS os Snapshots** (custo 100% zerado - $0.00/mês)

---

## 🔧 Gerenciamento Avançado

### Controle Individual do Bastion
```bash
scripts/stop-bastion.sh    # Desliga Bastion
scripts/delete-bastion.sh  # Deleta Bastion
```

### Controle Individual do RDS
```bash
scripts/start-rds.sh       # Liga RDS (2-5 min)
scripts/stop-rds.sh        # Desliga RDS (~50% economia)
scripts/delete-rds.sh      # Deleta RDS (com opção snapshot)
scripts/hibernate-rds.sh   # Snapshot + Delete
scripts/restore-rds.sh     # Restaura do snapshot
```

### Gerenciar Snapshots
```bash
scripts/list-snapshots.sh              # Lista todos snapshots
scripts/delete-snapshot.sh <id>        # Deleta snapshot específico
scripts/delete-all-snapshots.sh        # Deleta todos
```

### Utilidades
```bash
scripts/check-status.sh                # Verifica status dos recursos
scripts/cost-estimate.sh               # Estimativa de custos atual
scripts/backup.sh                      # Backup completo (snapshot + config)
scripts/recreate-infrastructure.sh     # Recria Bastion + RDS do snapshot
scripts/start-tunnel.sh                # Túnel sem auto-desligamento
```

---

## 🚀 Uso com Makefile (Opcional)

Se preferir comandos mais curtos:

```bash
make help              # Lista todos comandos
make setup             # Cria .env do template
make validate          # Valida ambiente
make deploy            # Deploy completo
make connect           # Conecta ao banco
make status            # Status dos recursos
make costs             # Estimativa de custos
make backup            # Backup completo
make destroy           # Deleta tudo
```

## 💰 Estimativa de Custos (us-east-1)

| Cenário | Custo Mensal | Recursos |
|---------|--------------|----------|
| **24/7 Ligado** | ~$12.41 | Bastion + RDS ligados |
| **Stop/Start Diário** | ~$6.21 | Desliga à noite |
| **Deletado com Snapshot** | ~$1.90 | Apenas backup (20GB) |
| **Destruído Completo** | $0.00 | Sem recursos (./destroy.sh) |

## 📂 Scripts Disponíveis

### Raiz (Comandos Principais)
- `deploy.sh` - Cria toda infraestrutura
- `connect.sh` - Conecta ao banco (auto-start/stop Bastion)
- `destroy.sh` - Deleta toda infraestrutura

### scripts/ (Gerenciamento Avançado)

**Provisionamento:**
- `provision-infrastructure.sh` - Cria infraestrutura (usado pelo deploy.sh)
- `destroy-all.sh` - Deleta tudo (pergunta sobre snapshots)

**Conexão:**
- `start-tunnel.sh` - Túnel sem auto-desligamento
- `connect-rds.sh` - (legado) Conecta com auto-stop

**Gerenciamento Bastion:**
- `stop-bastion.sh` - Desliga Bastion
- `delete-bastion.sh` - Deleta Bastion

**Gerenciamento RDS:**
- `start-rds.sh` - Liga RDS
- `stop-rds.sh` - Desliga RDS
- `delete-rds.sh` - Deleta RDS (com opção snapshot)
- `hibernate-rds.sh` - Snapshot + Delete
- `restore-rds.sh` - Restaura do snapshot

**Snapshots:**
- `list-snapshots.sh` - Lista snapshots
- `delete-snapshot.sh` - Deleta snapshot específico
- `delete-all-snapshots.sh` - Deleta todos snapshots

**Utilidades:**
- `check-status.sh` - Verifica status dos recursos
- `recreate-infrastructure.sh` - Recria Bastion + RDS do snapshot
- `config.sh` - Configurações centralizadas

## 🔒 Segurança

- ✅ RDS em subnet privada (sem acesso público)
- ✅ Acesso via SSM (sem SSH, sem chaves, sem portas abertas)
- ✅ Security Groups com regras mínimas (Zero Trust)
- ✅ Senha do banco solicitada interativamente (não fica no código)
- ✅ Tags obrigatórias em todos recursos (rastreabilidade)

## 🏷️ Tags Aplicadas

Todos os recursos são tagueados com:
- `Project`: Nome do projeto
- `Environment`: Ambiente (Prod/Dev/HML)
- `Name`: Nome descritivo do recurso

## 🔧 Troubleshooting

### Erro: "Porta 5433 já está em uso"
```bash
lsof -ti:5433 | xargs kill -9  # Mata processo na porta
```

### Erro: "SSM Agent timeout"
- Aguarde 2-3 minutos após iniciar o Bastion
- Verifique se a instância tem IAM role correto

### Erro: "Credenciais AWS inválidas"
```bash
aws configure  # Reconfigure credenciais
```

### Erro: "RDS está em estado: stopped"
```bash
scripts/start-rds.sh  # Liga o RDS
```

**📖 Guia completo:** Veja [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 📝 Notas Importantes

- RDS parado religa automaticamente após 7 dias (limitação AWS)
- Para evitar isso, use `scripts/hibernate-rds.sh` (snapshot + delete)
- **`./destroy.sh` deleta TUDO incluindo snapshots** (custo $0.00/mês)
- VPC e Security Groups são grátis (mas destroy.sh deleta tudo)
- Snapshots custam ~$0.095/GB/mês (apenas se mantidos manualmente)

## 🤝 Contribuindo

Sugestões e melhorias são bem-vindas!

## 📄 Licença

MIT License - Use livremente
