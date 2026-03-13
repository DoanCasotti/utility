#!/bin/bash
set -euo pipefail

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"
LOCAL_PORT="5433"
REMOTE_PORT="5432"

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

if lsof -Pi :"$LOCAL_PORT" -sTCP:LISTEN -t &> /dev/null; then
    echo "❌ Porta $LOCAL_PORT já está em uso"
    exit 1
fi

echo "🔍 Localizando Bastion..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
              "Name=tag:Environment,Values=$ENV" \
              "Name=tag:Name,Values=$BASTION_NAME" \
              "Name=instance-state-name,Values=stopped,running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$AWS_REGION")

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "❌ Bastion não encontrado"
    exit 1
fi

INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].State.Name" --output text --region "$AWS_REGION")

if [ "$INSTANCE_STATE" == "stopped" ]; then
    echo "⏳ Iniciando Bastion..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
fi

echo "⏳ Aguardando SSM Agent..."
for i in {1..12}; do
    if aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --query "InstanceInformationList[0].PingStatus" --output text --region "$AWS_REGION" 2>/dev/null | grep -q "Online"; then
        break
    fi
    [ $i -eq 12 ] && { echo "❌ SSM timeout"; exit 1; }
    sleep 5
done

echo "🔍 Obtendo endpoint RDS..."
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Address" \
    --output text --region "$AWS_REGION" 2>/dev/null)

if [ "$DB_ENDPOINT" == "None" ] || [ -z "$DB_ENDPOINT" ]; then
    echo "❌ RDS não encontrado"
    exit 1
fi

echo ""
echo "🔗 Túnel ativo em localhost:$LOCAL_PORT"
echo "⚠️  Use './stop-bastion.sh' para desligar o Bastion"
echo "⚠️  Pressione Ctrl+C para encerrar o túnel"
echo ""

aws ssm start-session \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$DB_ENDPOINT\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$AWS_REGION"
