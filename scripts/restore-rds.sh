#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Buscando último snapshot..."
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
    --query "sort_by(DBSnapshots[?contains(DBSnapshotIdentifier, '$DB_IDENTIFIER')], &SnapshotCreateTime)[-1].DBSnapshotIdentifier" \
    --output text --region "$AWS_REGION")

if [ "$SNAPSHOT_ID" == "None" ] || [ -z "$SNAPSHOT_ID" ]; then
    echo "❌ Nenhum snapshot encontrado para $DB_IDENTIFIER"
    exit 1
fi

echo "📋 Restaurando do snapshot: $SNAPSHOT_ID"

DB_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-RDS-SG" \
    --query "SecurityGroups[0].GroupId" \
    --output text --region "$AWS_REGION")

aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --db-instance-class db.t4g.micro \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --no-publicly-accessible \
    --vpc-security-group-ids "$DB_SG" \
    --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-RDS" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" \
    --region "$AWS_REGION"

echo "⏳ RDS sendo restaurado (leva ~5-10 minutos)"
echo "✅ Comando enviado com sucesso"
