#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Buscando todos os snapshots do projeto..."
SNAPSHOTS=$(aws rds describe-db-snapshots \
    --query "DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')].DBSnapshotIdentifier" \
    --output text --region "$AWS_REGION")

if [ -z "$SNAPSHOTS" ]; then
    echo "ℹ️  Nenhum snapshot encontrado"
    exit 0
fi

echo "📋 Snapshots encontrados:"
echo "$SNAPSHOTS" | tr '\t' '\n'
echo ""
read -p "⚠️  Deletar TODOS os snapshots acima? (s/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo "🗑️ Deletando snapshots..."
for SNAPSHOT in $SNAPSHOTS; do
    echo "  - Deletando: $SNAPSHOT"
    aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT" --region "$AWS_REGION" &> /dev/null
done

echo "✅ Todos os snapshots deletados - custo 100% zerado"
