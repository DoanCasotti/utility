#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Deploy com Terraform
# ==============================================================================

echo "🚀 Deploy da Infraestrutura com Terraform"
echo ""

# Verificar Terraform instalado
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não instalado"
    echo "💡 Instale: https://www.terraform.io/downloads"
    exit 1
fi

# Verificar terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  terraform.tfvars não encontrado"
    read -p "Criar do template? (s/N): " CREATE
    if [[ "$CREATE" =~ ^[Ss]$ ]]; then
        cp terraform.tfvars.example terraform.tfvars
        echo "✅ terraform.tfvars criado"
        echo "⚠️  Edite o arquivo antes de continuar"
        exit 0
    else
        exit 1
    fi
fi

# Solicitar senha do banco
read -sp "🔐 Digite a senha do banco RDS (mínimo 8 caracteres): " DB_PASS
echo

if [ ${#DB_PASS} -lt 8 ]; then
    echo "❌ Senha muito curta"
    exit 1
fi

# Validar senha
if [[ "$DB_PASS" =~ [@/\"\'] ]]; then
    echo "❌ Senha não pode conter: @ / \" '"
    exit 1
fi

export TF_VAR_db_password="$DB_PASS"

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

echo ""
echo "✅ Deploy completo!"
echo ""
terraform output -json | jq -r '
"📋 Informações da Infraestrutura:",
"",
"VPC ID: " + .vpc_id.value,
"Bastion ID: " + .bastion_instance_id.value,
"RDS Endpoint: " + .rds_address.value,
"",
"💰 Estimativa de Custos (us-east-1):",
"   • Bastion (t3.nano): ~$3.80/mês",
"   • RDS (db.t4g.micro): ~$12.41/mês",
"   • Storage (20GB gp3): ~$1.60/mês",
"   • TOTAL: ~$17.81/mês",
"",
"🔗 Use ./connect.sh para conectar ao banco"
'
