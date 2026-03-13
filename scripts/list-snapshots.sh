#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Listando snapshots do projeto..."
SNAPSHOTS=$(aws rds describe-db-snapshots \
    --query "DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')].{ID:DBSnapshotIdentifier,Size:AllocatedStorage,Date:SnapshotCreateTime}" \
    --output table --region "$AWS_REGION")

if [ -z "$SNAPSHOTS" ]; then
    echo "ℹ️  Nenhum snapshot encontrado"
    exit 0
fi

echo "$SNAPSHOTS"
