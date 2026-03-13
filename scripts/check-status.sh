#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Verificando status da infraestrutura..."
echo ""

# VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-VPC" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "✅ VPC: $VPC_ID"
else
    echo "❌ VPC: Não encontrada"
fi

# Bastion
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
              "Name=tag:Environment,Values=$ENV" \
              "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-Bastion" \
              "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query "Reservations[0].Instances[0].[InstanceId,State.Name]" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "None None")

BASTION_ID=$(echo "$INSTANCE_ID" | awk '{print $1}')
BASTION_STATE=$(echo "$INSTANCE_ID" | awk '{print $2}')

if [ "$BASTION_ID" != "None" ] && [ -n "$BASTION_ID" ]; then
    echo "✅ Bastion: $BASTION_ID ($BASTION_STATE)"
else
    echo "❌ Bastion: Não encontrado"
fi

# RDS
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
RDS_INFO=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].[DBInstanceStatus,Endpoint.Address]" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "None None")

RDS_STATUS=$(echo "$RDS_INFO" | awk '{print $1}')
RDS_ENDPOINT=$(echo "$RDS_INFO" | awk '{print $2}')

if [ "$RDS_STATUS" != "None" ] && [ -n "$RDS_STATUS" ]; then
    echo "✅ RDS: $DB_IDENTIFIER ($RDS_STATUS)"
    [ "$RDS_ENDPOINT" != "None" ] && echo "   Endpoint: $RDS_ENDPOINT"
else
    echo "❌ RDS: Não encontrado"
fi

# Snapshots
SNAPSHOT_COUNT=$(aws rds describe-db-snapshots \
    --query "length(DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')])" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "0")

if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
    echo "✅ Snapshots: $SNAPSHOT_COUNT encontrado(s)"
else
    echo "ℹ️  Snapshots: Nenhum"
fi

# Security Groups
SG_COUNT=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENV" \
    --query "length(SecurityGroups)" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "0")

echo "ℹ️  Security Groups: $SG_COUNT"

echo ""
echo "📊 Resumo:"
[ "$VPC_ID" != "None" ] && echo "   Infraestrutura base: ✅ Provisionada" || echo "   Infraestrutura base: ❌ Não provisionada"
[ "$BASTION_ID" != "None" ] && echo "   Bastion: ✅ Existe" || echo "   Bastion: ❌ Não existe"
[ "$RDS_STATUS" != "None" ] && echo "   RDS: ✅ Existe" || echo "   RDS: ❌ Não existe"
