#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
SNAPSHOT_ID="${DB_IDENTIFIER}-final-$(date +%Y%m%d-%H%M%S)"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Verificando RDS..."
DB_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].DBInstanceStatus" \
    --output text --region "$AWS_REGION" 2>/dev/null)

if [ "$DB_STATUS" == "None" ] || [ -z "$DB_STATUS" ]; then
    echo "ℹ️  RDS não encontrado ou já deletado"
    exit 0
fi

read -p "⚠️  Criar snapshot antes de deletar? (s/N): " CREATE_SNAPSHOT

if [[ "$CREATE_SNAPSHOT" =~ ^[Ss]$ ]]; then
    echo "📸 Criando snapshot final..."
    aws rds create-db-snapshot \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --db-snapshot-identifier "$SNAPSHOT_ID" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" \
        --region "$AWS_REGION"
    
    echo "⏳ Aguardando snapshot..."
    aws rds wait db-snapshot-completed --db-snapshot-identifier "$SNAPSHOT_ID" --region "$AWS_REGION"
    echo "✅ Snapshot criado: $SNAPSHOT_ID"
fi

echo "🗑️ Deletando RDS ($DB_IDENTIFIER)..."
aws rds delete-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --skip-final-snapshot \
    --region "$AWS_REGION" &> /dev/null

echo "✅ RDS deletado - custo zerado"
[ -n "${SNAPSHOT_ID:-}" ] && echo "📋 Snapshot disponível para restauração: $SNAPSHOT_ID"
