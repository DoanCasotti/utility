# 🚀 AWS DevOps Utility

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![Bash](https://img.shields.io/badge/Bash-Script-green?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Coleção de utilitários para automação de infraestrutura AWS.

## 📂 Estrutura do Projeto

```
utility/
├── projeto-sh/          # Infraestrutura AWS Automatizada
│   ├── deploy.sh       # Deploy completo
│   ├── connect.sh      # Conectar ao banco
│   ├── destroy.sh      # Destruir infraestrutura
│   ├── validate.sh     # Validar ambiente
│   ├── scripts/        # Scripts auxiliares
│   └── README.md       # Documentação completa
│
└── .env.example        # Template de configuração
```

## 🚀 Quick Start

### 1. Configurar Ambiente

```bash
# Copiar template
cp .env.example .env

# Editar configurações
nano .env
```

### 2. Usar Projeto

```bash
cd projeto-sh

# Validar ambiente
./validate.sh

# Deploy
./deploy.sh

# Conectar
./connect.sh

# Destruir
./destroy.sh
```

## 📚 Documentação

Cada projeto tem sua documentação completa:

- **[projeto-sh/README.md](projeto-sh/README.md)** - Infraestrutura AWS completa

## 🔧 Projetos Disponíveis

### 🏗️ projeto-sh - Infraestrutura AWS

Infraestrutura completa para RDS PostgreSQL privado com Bastion Host via SSM.

**Recursos:**
- ✅ VPC isolada com subnets públicas e privadas
- ✅ Bastion Host com acesso via SSM (sem SSH)
- ✅ RDS PostgreSQL em subnet privada
- ✅ Controle total de custos
- ✅ Scripts de backup e restore
- ✅ Estimativa de custos em tempo real

**[Ver documentação completa →](projeto-sh/README.md)**

## 📝 Licença

MIT License - Veja [LICENSE](LICENSE)
