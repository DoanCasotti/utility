#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Backup Completo - Snapshot de RDS + Exportar Configuração
# ==============================================================================

# Carregar variáveis do .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
else
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi

if [ -n "${AWS_PROFILE:-}" ] && [ "$AWS_PROFILE" != "default" ]; then
    export AWS_PROFILE
fi

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_ID="${DB_IDENTIFIER}-backup-${TIMESTAMP}"
BACKUP_DIR="$SCRIPT_DIR/../backups"

echo "💾 Iniciando backup completo..."

# Criar diretório de backups
mkdir -p "$BACKUP_DIR"

# 1. Snapshot do RDS
echo "📸 Criando snapshot do RDS..."
aws rds create-db-snapshot \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" Key=Type,Value=Backup \
    --region "$AWS_REGION"

echo "⏳ Aguardando snapshot completar..."
aws rds wait db-snapshot-completed --db-snapshot-identifier "$SNAPSHOT_ID" --region "$AWS_REGION"

# 2. Exportar configuração
echo "📝 Exportando configuração..."
cat > "$BACKUP_DIR/backup-${TIMESTAMP}.info" <<EOF
# Backup Information
Date: $(date)
Project: $PROJECT_NAME
Environment: $ENV
Region: $AWS_REGION
Snapshot ID: $SNAPSHOT_ID
DB Identifier: $DB_IDENTIFIER

# Restore Command:
# scripts/restore-from-backup.sh $SNAPSHOT_ID
EOF

# 3. Copiar .env
cp "$SCRIPT_DIR/../.env" "$BACKUP_DIR/.env-${TIMESTAMP}.backup"

echo ""
echo "✅ Backup completo finalizado!"
echo "📋 Snapshot: $SNAPSHOT_ID"
echo "📁 Configuração: $BACKUP_DIR/backup-${TIMESTAMP}.info"
echo ""
echo "💰 Custo do snapshot: ~$0.095/GB/mês (20GB = ~$1.90/mês)"
