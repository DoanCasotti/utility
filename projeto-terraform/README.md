# 🚀 AWS DevOps Infrastructure - Terraform

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)

Infraestrutura AWS completa usando **Terraform** com as melhores práticas de IaC (Infrastructure as Code).

## 🎯 O que este projeto faz

Provisiona automaticamente:
- ✅ VPC isolada com subnets públicas e privadas
- ✅ Bastion Host com acesso via SSM (sem SSH)
- ✅ RDS PostgreSQL em subnet privada
- ✅ Security Groups com Zero Trust
- ✅ IAM Roles e Policies

## 📋 Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado
- Session Manager Plugin (para conectar)
- jq (opcional, para outputs formatados)

## 🚀 Quick Start

### 1. Validar Ambiente
```bash
scripts/validate.sh
```

### 2. Configurar Variáveis
```bash
cp .env.example .env
nano .env
```

### 3. Deploy
```bash
scripts/deploy.sh
# Gera terraform.tfvars automaticamente do .env
# Solicita senha do banco
# Salva outputs em terraform-outputs.json
```

### 4. Conectar ao Banco
```bash
scripts/connect.sh
# Usa terraform-outputs.json automaticamente
```

### 5. Destruir Tudo
```bash
scripts/destroy.sh
```

## 📁 Estrutura de Arquivos

```
projeto-terraform/
├── main.tf                  # Provider e configuração
├── variables.tf             # Variáveis
├── vpc.tf                   # VPC e Networking
├── security.tf              # Security Groups
├── iam.tf                   # IAM Roles
├── bastion.tf               # Bastion EC2
├── rds.tf                   # RDS PostgreSQL
├── outputs.tf               # Outputs
├── .env.example             # Template de configuração
├── terraform.tfvars.example # Template Terraform (gerado auto do .env)
├── terraform-outputs.json   # Outputs salvos (gerado no deploy)
└── scripts/
    ├── deploy.sh            # Deploy automatizado
    ├── connect.sh           # Conexão (usa outputs)
    ├── destroy.sh           # Destruição completa
    └── validate.sh          # Validação de ambiente
```

## 💰 Estimativa de Custos (us-east-1)

| Recurso | Custo Mensal |
|---------|--------------|
| Bastion (t3.nano) | ~$3.80 |
| RDS (db.t4g.micro) | ~$12.41 |
| Storage (20GB gp3) | ~$1.60 |
| **TOTAL** | **~$17.81** |

## 🔧 Comandos Terraform

```bash
# Inicializar
terraform init

# Planejar
terraform plan

# Aplicar
terraform apply

# Destruir
terraform destroy

# Ver outputs
terraform output

# Formatar código
terraform fmt -recursive

# Validar sintaxe
terraform validate
```

## 🆚 Terraform vs Shell Scripts

| Aspecto | Terraform | Shell Scripts |
|---------|-----------|---------------|
| **Idempotência** | ✅ Nativo | ⚠️ Manual |
| **State Management** | ✅ Automático | ❌ Não tem |
| **Rollback** | ✅ Fácil | ⚠️ Complexo |
| **Visualização** | ✅ Plan/Graph | ❌ Não tem |
| **Reutilização** | ✅ Modules | ⚠️ Limitado |
| **Curva de Aprendizado** | ⚠️ Média | ✅ Baixa |

## 📝 Notas Importantes

- State file é local (considere usar S3 backend para produção)
- `destroy.sh` deleta TUDO (custo $0.00/mês)
- Senha do banco não é armazenada no state (sensitive)
- Tags são aplicadas automaticamente via provider

## 🔒 Segurança

- ✅ RDS em subnet privada
- ✅ Acesso via SSM (sem SSH)
- ✅ Security Groups restritivos
- ✅ Senha sensível (não aparece em logs)
- ✅ Storage criptografado

## 📚 Documentação

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC](https://docs.aws.amazon.com/vpc/)
- [AWS RDS](https://docs.aws.amazon.com/rds/)
- [AWS SSM](https://docs.aws.amazon.com/systems-manager/)
