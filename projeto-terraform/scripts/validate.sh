#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Validação de Pré-requisitos (Terraform)
# ==============================================================================

echo "🔍 Validando ambiente Terraform..."
echo ""

# 1. Verificar Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não instalado"
    echo "💡 Instale: https://www.terraform.io/downloads"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo "✅ Terraform instalado (v$TERRAFORM_VERSION)"

# 2. Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não instalado"
    echo "💡 Instale: https://aws.amazon.com/cli/"
    exit 1
fi
echo "✅ AWS CLI instalado"

# 3. Verificar credenciais AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    echo "💡 Execute: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
echo "✅ Credenciais AWS válidas"
echo "   Conta: $AWS_ACCOUNT"
echo "   Usuário: $AWS_USER"

# 4. Verificar terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  terraform.tfvars não encontrado"
    echo "💡 Execute: cp terraform.tfvars.example terraform.tfvars"
else
    echo "✅ terraform.tfvars encontrado"
fi

# 5. Verificar Session Manager Plugin
if ! command -v session-manager-plugin &> /dev/null; then
    echo "⚠️  Session Manager Plugin não instalado"
    echo "💡 Necessário para conectar ao banco"
else
    echo "✅ Session Manager Plugin instalado"
fi

# 6. Verificar jq (para outputs)
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq não instalado (opcional)"
    echo "💡 Instale para melhor visualização dos outputs"
else
    echo "✅ jq instalado"
fi

echo ""
echo "✅ Ambiente validado com sucesso!"
echo "🚀 Você pode executar: ./deploy.sh"
