#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Setup Git e Push para GitHub
# ==============================================================================

echo "🚀 Setup Git para o Projeto"
echo ""

# Verificar se já é um repositório Git
if [ -d ".git" ]; then
    echo "✅ Repositório Git já inicializado"
else
    echo "📦 Inicializando repositório Git..."
    git init
    echo "✅ Git inicializado"
fi

# Verificar se .env existe e avisar
if [ -f ".env" ]; then
    echo ""
    echo "⚠️  ATENÇÃO: Arquivo .env detectado"
    echo "   O .env está no .gitignore e NÃO será commitado (seguro)"
fi

# Verificar .gitignore
if [ ! -f ".gitignore" ]; then
    echo "❌ .gitignore não encontrado!"
    exit 1
fi

echo ""
echo "📋 Arquivos que serão commitados:"
git add -n . | head -20
echo ""

read -p "Continuar com o commit? (s/N): " CONTINUE
if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

# Adicionar arquivos
echo "📦 Adicionando arquivos..."
git add .

# Verificar se há mudanças
if git diff --cached --quiet; then
    echo "ℹ️  Nenhuma mudança para commitar"
    exit 0
fi

# Commit
echo ""
read -p "Mensagem do commit (ou Enter para padrão): " COMMIT_MSG
if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="feat: Initial commit - AWS DevOps Infrastructure

- Infraestrutura completa VPC + Bastion + RDS
- Scripts de deploy, connect e destroy
- Validação de ambiente e estimativa de custos
- Documentação completa e troubleshooting"
fi

git commit -m "$COMMIT_MSG"
echo "✅ Commit realizado"

# Configurar remote
echo ""
echo "🔗 Configurar repositório remoto no GitHub"
echo ""
echo "1. Acesse: https://github.com/new"
echo "2. Crie um novo repositório"
echo "3. NÃO marque 'Initialize with README'"
echo ""
read -p "URL do repositório (ex: https://github.com/usuario/repo.git): " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "❌ URL não fornecida"
    exit 1
fi

# Verificar se remote já existe
if git remote | grep -q "origin"; then
    echo "⚠️  Remote 'origin' já existe"
    read -p "Substituir? (s/N): " REPLACE
    if [[ "$REPLACE" =~ ^[Ss]$ ]]; then
        git remote remove origin
        git remote add origin "$REPO_URL"
    fi
else
    git remote add origin "$REPO_URL"
fi

# Push
echo ""
echo "📤 Enviando para o GitHub..."
git branch -M main
git push -u origin main

echo ""
echo "✅ Projeto enviado para o GitHub com sucesso!"
echo "🌐 Acesse: ${REPO_URL%.git}"
