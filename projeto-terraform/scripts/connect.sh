#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Conectar ao RDS via Bastion (Terraform)
# ==============================================================================

cd "$(dirname "$0")/.."

# Carregar .env
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
else
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi

# Verificar se terraform-outputs.json existe
if [ ! -f "terraform-outputs.json" ]; then
    echo "❌ terraform-outputs.json não encontrado"
    echo "💡 Execute: scripts/deploy.sh primeiro"
    exit 1
fi

# Extrair informações do Terraform
INSTANCE_ID=$(jq -r '.bastion_instance_id.value' terraform-outputs.json)
RDS_ADDRESS=$(jq -r '.rds_address.value' terraform-outputs.json)

if [ "$INSTANCE_ID" == "null" ] || [ -z "$INSTANCE_ID" ]; then
    echo "❌ Bastion não encontrado nos outputs"
    exit 1
fi

if [ "$RDS_ADDRESS" == "null" ] || [ -z "$RDS_ADDRESS" ]; then
    echo "❌ RDS não encontrado nos outputs"
    exit 1
fi

# Validações
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

if lsof -Pi :"$LOCAL_PORT" -sTCP:LISTEN -t &> /dev/null; then
    echo "❌ Porta $LOCAL_PORT já está em uso"
    exit 1
fi

# Cleanup automático
cleanup() {
    if [ -n "${INSTANCE_ID:-}" ]; then
        echo ""
        echo "🛑 Túnel encerrado"
        echo "⏳ Desligando Bastion em 10 segundos..."
        echo "   (Pressione Ctrl+C novamente para cancelar)"
        sleep 10 2>/dev/null || { echo "❌ Cancelado - Bastion continua ligado"; exit 0; }
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null || true
        echo "✅ Bastion desligado - custos zerados"
    fi
}
trap cleanup EXIT INT TERM

echo "🔍 Verificando Bastion..."
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].State.Name" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$INSTANCE_STATE" == "None" ]; then
    echo "❌ Bastion não encontrado"
    exit 1
fi

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

echo "🔍 Verificando RDS..."
RDS_STATUS=$(aws rds describe-db-instances --query "DBInstances[?Endpoint.Address=='$RDS_ADDRESS'].DBInstanceStatus" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$RDS_STATUS" == "None" ] || [ -z "$RDS_STATUS" ]; then
    echo "❌ RDS não encontrado"
    exit 1
fi

if [ "$RDS_STATUS" != "available" ]; then
    echo "⚠️  RDS está em estado: $RDS_STATUS"
    if [ "$RDS_STATUS" == "stopped" ]; then
        echo "💡 Execute: aws rds start-db-instance --db-instance-identifier <id>"
    fi
    exit 1
fi

echo ""
echo "🔗 Túnel ativo em localhost:$LOCAL_PORT"
echo "⚠️  Pressione Ctrl+C para encerrar"
echo "ℹ️  Bastion será desligado automaticamente 10s após fechar o túnel"
echo ""

aws ssm start-session \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$RDS_ADDRESS\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$AWS_REGION"
