#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Validação de Pré-requisitos
# ==============================================================================

echo "🔍 Validando ambiente..."

# 1. Verificar .env
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env não encontrado"
    echo "💡 Execute: cp .env.example .env"
    exit 1
fi
echo "✅ Arquivo .env encontrado"

# 2. Carregar .env
set -a
source .env
set +a

# 3. Verificar variáveis obrigatórias
REQUIRED_VARS=("PROJECT_NAME" "ENV" "AWS_REGION" "DB_USER")
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        echo "❌ Variável $VAR não definida no .env"
        exit 1
    fi
done
echo "✅ Variáveis obrigatórias definidas"

# 4. Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não instalado"
    echo "💡 Instale: https://aws.amazon.com/cli/"
    exit 1
fi
echo "✅ AWS CLI instalado"

# 5. Verificar credenciais AWS
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

# 6. Verificar permissões básicas
echo "🔍 Verificando permissões AWS..."
PERMISSIONS_OK=true

if ! aws ec2 describe-vpcs --max-results 1 &> /dev/null; then
    echo "❌ Sem permissão EC2"
    PERMISSIONS_OK=false
fi

if ! aws rds describe-db-instances --max-records 1 &> /dev/null; then
    echo "❌ Sem permissão RDS"
    PERMISSIONS_OK=false
fi

if ! aws iam list-roles --max-items 1 &> /dev/null; then
    echo "❌ Sem permissão IAM"
    PERMISSIONS_OK=false
fi

if [ "$PERMISSIONS_OK" = true ]; then
    echo "✅ Permissões AWS OK"
else
    echo "⚠️  Algumas permissões estão faltando"
    exit 1
fi

# 7. Verificar Session Manager Plugin
if ! command -v session-manager-plugin &> /dev/null; then
    echo "⚠️  Session Manager Plugin não instalado"
    echo "💡 Instale: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    echo "   (Necessário apenas para conectar ao banco)"
else
    echo "✅ Session Manager Plugin instalado"
fi

echo ""
echo "✅ Ambiente validado com sucesso!"
echo "🚀 Você pode executar: ./deploy.sh"
