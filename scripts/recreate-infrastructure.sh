#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"
DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "🔍 Buscando último snapshot..."
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
    --query "sort_by(DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}-rds')], &SnapshotCreateTime)[-1].DBSnapshotIdentifier" \
    --output text --region "$AWS_REGION")

if [ "$SNAPSHOT_ID" == "None" ] || [ -z "$SNAPSHOT_ID" ]; then
    echo "❌ Nenhum snapshot encontrado"
    exit 1
fi

echo "📋 Snapshot encontrado: $SNAPSHOT_ID"

# Restaurar Bastion
echo "🖥️ Recriando Bastion..."
BASTION_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-Bastion-SG" \
    --query "SecurityGroups[0].GroupId" \
    --output text --region "$AWS_REGION")

SUBNET_PUB=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-Subnet-Pub-*" \
    --query "Subnets[0].SubnetId" \
    --output text --region "$AWS_REGION")

PROFILE_NAME="${PROJECT_NAME}${ENV}BastionProfile"

AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text --region "$AWS_REGION")

aws ec2 run-instances \
    --image-id "$AMI_ID" --count 1 --instance-type t3.nano \
    --security-group-ids "$BASTION_SG" --subnet-id "$SUBNET_PUB" \
    --iam-instance-profile Name="$PROFILE_NAME" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${BASTION_NAME}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENV}}]" \
    --region "$AWS_REGION" &> /dev/null

echo "✅ Bastion recriado"

# Restaurar RDS
echo "🗄️ Restaurando RDS do snapshot..."
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
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
    --region "$AWS_REGION" &> /dev/null

echo "✅ RDS sendo restaurado (5-10 minutos)"
echo "🎉 Infraestrutura sendo recriada!"
