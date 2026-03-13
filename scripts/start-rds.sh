#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Verificando status do RDS..."
DB_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].DBInstanceStatus" \
    --output text --region "$AWS_REGION" 2>/dev/null)

if [ "$DB_STATUS" == "None" ] || [ -z "$DB_STATUS" ]; then
    echo "❌ RDS '$DB_IDENTIFIER' não encontrado"
    exit 1
fi

if [ "$DB_STATUS" == "available" ]; then
    echo "ℹ️  RDS já está ligado"
    exit 0
fi

if [ "$DB_STATUS" != "stopped" ]; then
    echo "⚠️  RDS está em estado: $DB_STATUS (aguarde finalizar operação atual)"
    exit 1
fi

echo "⏳ Ligando RDS ($DB_IDENTIFIER)..."
aws rds start-db-instance --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION" &> /dev/null
echo "✅ RDS sendo iniciado (leva ~2-5 minutos)"
