#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

if [ -z "${1:-}" ]; then
    echo "❌ Uso: ./delete-snapshot.sh <snapshot-id>"
    echo ""
    echo "📋 Snapshots disponíveis:"
    aws rds describe-db-snapshots \
        --query "DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')].DBSnapshotIdentifier" \
        --output text --region "$AWS_REGION" | tr '\t' '\n'
    exit 1
fi

SNAPSHOT_ID="$1"

echo "🗑️ Deletando snapshot: $SNAPSHOT_ID"
aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT_ID" --region "$AWS_REGION" &> /dev/null
echo "✅ Snapshot deletado - custo zerado"
