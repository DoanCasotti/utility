#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

echo "⚠️  ATENÇÃO: Isso deletará TODA a infraestrutura!"
echo "   - VPC e Subnets"
echo "   - Security Groups"
echo "   - IAM Roles e Profiles"
echo "   - Bastion e RDS"
echo "   - Snapshots (opcional)"
echo ""
read -p "Confirmar destruição completa? (digite 'DELETAR'): " CONFIRM

if [ "$CONFIRM" != "DELETAR" ]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo "🗑️ Iniciando destruição..."

# 1. Deletar Bastion
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
              "Name=tag:Environment,Values=$ENV" \
              "Name=instance-state-name,Values=running,stopped,stopping" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    echo "  🖥️  Deletando Bastion..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" 2>/dev/null || true
fi

# 2. Deletar RDS
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
if aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION" &> /dev/null; then
    echo "  🗄️  Deletando RDS..."
    aws rds delete-db-instance --db-instance-identifier "$DB_IDENTIFIER" --skip-final-snapshot --region "$AWS_REGION" &> /dev/null
    echo "     Aguardando deleção do RDS (pode levar 5 minutos)..."
    aws rds wait db-instance-deleted --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION" 2>/dev/null || true
fi

# 3. Deletar DB Subnet Group
DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"
if aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GROUP" --region "$AWS_REGION" &> /dev/null; then
    echo "  📦 Deletando DB Subnet Group..."
    aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP" --region "$AWS_REGION" &> /dev/null
fi

# 4. Obter IDs dos recursos
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-VPC" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "ℹ️  VPC não encontrada - infraestrutura já deletada"
    exit 0
fi

# 5. Deletar Security Groups (exceto default)
echo "  🛡️  Deletando Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text --region "$AWS_REGION")
for SG in $SG_IDS; do
    aws ec2 delete-security-group --group-id "$SG" --region "$AWS_REGION" 2>/dev/null || true
done

# 6. Deletar Subnets
echo "  🏗️  Deletando Subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text --region "$AWS_REGION")
for SUBNET in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$AWS_REGION" 2>/dev/null || true
done

# 7. Deletar Route Tables (exceto main)
echo "  🛣️  Deletando Route Tables..."
RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text --region "$AWS_REGION")
for RT in $RT_IDS; do
    aws ec2 delete-route-table --route-table-id "$RT" --region "$AWS_REGION" 2>/dev/null || true
done

# 8. Detach e Deletar Internet Gateway
echo "  🌐 Deletando Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$AWS_REGION" 2>/dev/null || true
fi

# 9. Deletar VPC
echo "  🗑️  Deletando VPC..."
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null || true

# 10. Deletar IAM
echo "  🔑 Deletando IAM Roles..."
ROLE_NAME="${PROJECT_NAME}${ENV}BastionRole"
PROFILE_NAME="${PROJECT_NAME}${ENV}BastionProfile"

aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME" 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME" 2>/dev/null || true
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true

# 11. Snapshots (opcional)
read -p "Deletar snapshots também? (s/N): " DELETE_SNAPS
if [[ "$DELETE_SNAPS" =~ ^[Ss]$ ]]; then
    echo "  📸 Deletando snapshots..."
    SNAPSHOTS=$(aws rds describe-db-snapshots --query "DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')].DBSnapshotIdentifier" --output text --region "$AWS_REGION" 2>/dev/null || echo "")
    for SNAPSHOT in $SNAPSHOTS; do
        aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT" --region "$AWS_REGION" &> /dev/null || true
    done
fi

echo ""
echo "✅ Infraestrutura completamente destruída!"
echo "💰 Custo zerado (exceto snapshots se mantidos)"
