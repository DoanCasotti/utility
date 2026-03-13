#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Destruir TUDO - VPC, Subnets, SGs, IAM, Bastion, RDS, Snapshots
# ==============================================================================

# Carregar variáveis do .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
else
    echo "❌ Arquivo .env não encontrado. Copie .env.example para .env"
    exit 1
fi

# Configurar AWS Profile se especificado
if [ -n "${AWS_PROFILE:-}" ] && [ "$AWS_PROFILE" != "default" ]; then
    export AWS_PROFILE
fi

# Variáveis derivadas
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"
ROLE_NAME="${PROJECT_NAME}${ENV}BastionRole"
PROFILE_NAME="${PROJECT_NAME}${ENV}BastionProfile"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

# Mostrar conta AWS em uso
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "📋 Conta AWS: $AWS_ACCOUNT"
echo ""

echo "⚠️  ATENÇÃO: Isso deletará TODA a infraestrutura!"
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  RECURSOS QUE SERÃO DELETADOS:                    ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  ✗ VPC e Subnets                                  ║"
echo "║  ✗ Security Groups                                ║"
echo "║  ✗ IAM Roles e Profiles                           ║"
echo "║  ✗ Bastion EC2                                    ║"
echo "║  ✗ RDS PostgreSQL                                 ║"
echo "║  ✗ TODOS os Snapshots RDS                         ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  💰 CUSTO FINAL: $0.00/mês                         ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
read -p "Confirmar destruição completa? (digite 'DELETAR'): " CONFIRM

if [ "$CONFIRM" != "DELETAR" ]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo "🗑️ Iniciando destruição completa (custo ZERO)..."

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

# 4. Obter VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-VPC" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "ℹ️  VPC não encontrada"
else
    # 5. Deletar Security Groups
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

    # 7. Deletar Route Tables
    echo "  🛣️  Deletando Route Tables..."
    RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text --region "$AWS_REGION")
    for RT in $RT_IDS; do
        aws ec2 delete-route-table --route-table-id "$RT" --region "$AWS_REGION" 2>/dev/null || true
    done

    # 8. Deletar Internet Gateway
    echo "  🌐 Deletando Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null || true
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$AWS_REGION" 2>/dev/null || true
    fi

    # 9. Deletar VPC
    echo "  🗑️  Deletando VPC..."
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null || true
fi

# 10. Deletar IAM
echo "  🔑 Deletando IAM Roles..."
ROLE_NAME="${PROJECT_NAME}${ENV}BastionRole"
PROFILE_NAME="${PROJECT_NAME}${ENV}BastionProfile"

aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME" 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME" 2>/dev/null || true
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true

# 11. Deletar Snapshots
echo "  📸 Deletando snapshots..."
SNAPSHOTS=$(aws rds describe-db-snapshots --query "DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')].DBSnapshotIdentifier" --output text --region "$AWS_REGION" 2>/dev/null || echo "")
SNAPSHOT_COUNT=0
for SNAPSHOT in $SNAPSHOTS; do
    echo "     Deletando: $SNAPSHOT"
    aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT" --region "$AWS_REGION" &> /dev/null || true
    SNAPSHOT_COUNT=$((SNAPSHOT_COUNT + 1))
done

if [ $SNAPSHOT_COUNT -gt 0 ]; then
    echo "     ✅ $SNAPSHOT_COUNT snapshot(s) deletado(s)"
else
    echo "     ℹ️  Nenhum snapshot encontrado"
fi

echo ""
echo "✅ Infraestrutura completamente destruída!"
echo "💰 Custo 100% zerado - Nenhum recurso AWS restante"
echo ""
echo "📊 Recursos deletados:"
echo "   • VPC e Subnets"
echo "   • Security Groups"
echo "   • IAM Roles"
echo "   • Bastion EC2"
echo "   • RDS PostgreSQL"
echo "   • Snapshots RDS"
