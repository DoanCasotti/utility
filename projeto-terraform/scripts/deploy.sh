#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Deploy com Terraform
# ==============================================================================

cd "$(dirname "$0")/.."

echo "🚀 Deploy da Infraestrutura com Terraform"
echo ""

# Verificar Terraform instalado
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não instalado"
    echo "💡 Instale: https://www.terraform.io/downloads"
    exit 1
fi

# Verificar .env
if [ ! -f ".env" ]; then
    echo "⚠️  .env não encontrado"
    read -p "Criar do template? (s/N): " CREATE
    if [[ "$CREATE" =~ ^[Ss]$ ]]; then
        cp .env.example .env
        echo "✅ .env criado"
        echo "⚠️  Edite o arquivo antes de continuar"
        exit 0
    else
        exit 1
    fi
fi

# Carregar .env
set -a
source .env
set +a

# Solicitar senha do banco
read -sp "🔐 Digite a senha do banco RDS (mínimo 8 caracteres): " DB_PASSWORD
echo

if [ ${#DB_PASSWORD} -lt 8 ]; then
    echo "❌ Senha muito curta"
    exit 1
fi

if [[ "$DB_PASSWORD" =~ [@/\"\'] ]]; then
    echo "❌ Senha não pode conter: @ / \" '"
    exit 1
fi

# Criar terraform.tfvars automaticamente do .env
cat > terraform.tfvars <<EOF
# Gerado automaticamente do .env
project_name          = "$PROJECT_NAME"
environment           = "$ENVIRONMENT"
aws_region            = "$AWS_REGION"
aws_profile           = "$AWS_PROFILE"
db_username           = "$DB_USERNAME"
db_password           = "$DB_PASSWORD"
bastion_instance_type = "$BASTION_INSTANCE_TYPE"
rds_instance_class    = "$RDS_INSTANCE_CLASS"
rds_allocated_storage = $RDS_ALLOCATED_STORAGE
EOF

echo "✅ terraform.tfvars gerado do .env"

# Inicializar Terraform
if [ ! -d ".terraform" ]; then
    echo "📦 Inicializando Terraform..."
    terraform init
fi

# Plan
echo ""
echo "📋 Planejando mudanças..."
terraform plan -out=tfplan

# Confirmar
echo ""
read -p "Aplicar mudanças? (s/N): " APPLY
if [[ ! "$APPLY" =~ ^[Ss]$ ]]; then
    echo "❌ Deploy cancelado"
    rm -f tfplan
    exit 0
fi

# Apply
echo ""
echo "🚀 Aplicando infraestrutura..."
terraform apply tfplan
rm -f tfplan

# Salvar outputs em JSON para scripts usarem
echo ""
echo "💾 Salvando outputs..."
terraform output -json > terraform-outputs.json

# Extrair informações importantes
BASTION_ID=$(terraform output -raw bastion_instance_id 2>/dev/null || echo "")
RDS_ADDRESS=$(terraform output -raw rds_address 2>/dev/null || echo "")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")

echo ""
echo "✅ Deploy completo!"
echo ""
echo "📋 Informações da Infraestrutura:"
echo "   VPC ID: $VPC_ID"
echo "   Bastion ID: $BASTION_ID"
echo "   RDS Endpoint: $RDS_ADDRESS"
echo ""
echo "💰 Estimativa de Custos (us-east-1):"
echo "   • Bastion (t3.nano): ~\$3.80/mês"
echo "   • RDS (db.t4g.micro): ~\$12.41/mês"
echo "   • Storage (20GB gp3): ~\$1.60/mês"
echo "   • TOTAL: ~\$17.81/mês"
echo ""
echo "📄 Outputs salvos em: terraform-outputs.json"
echo "🔗 Use scripts/connect.sh para conectar ao banco"
