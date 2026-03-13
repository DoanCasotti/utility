#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
SNAPSHOT_ID="${DB_IDENTIFIER}-$(date +%Y%m%d-%H%M%S)"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "📸 Criando snapshot do RDS..."
aws rds create-db-snapshot \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" \
    --region "$AWS_REGION"

echo "⏳ Aguardando snapshot completar..."
aws rds wait db-snapshot-completed --db-snapshot-identifier "$SNAPSHOT_ID" --region "$AWS_REGION"

echo "🗑️ Deletando instância RDS..."
aws rds delete-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --skip-final-snapshot \
    --region "$AWS_REGION" &> /dev/null

echo "✅ RDS deletado - custo reduzido a ~95%"
echo "📋 Snapshot: $SNAPSHOT_ID"
echo "ℹ️  Use './restore-rds.sh' para restaurar quando precisar"
