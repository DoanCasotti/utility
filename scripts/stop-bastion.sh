#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Localizando Bastion..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
              "Name=tag:Environment,Values=$ENV" \
              "Name=tag:Name,Values=$BASTION_NAME" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$AWS_REGION")

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "ℹ️  Bastion já está desligado ou não encontrado"
    exit 0
fi

echo "🛑 Desligando Bastion ($INSTANCE_ID)..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null
echo "✅ Bastion desligado - custos zerados"
