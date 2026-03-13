#!/bin/bash

# ==============================================================================
# Script: Inicialização Rápida do Projeto
# ==============================================================================

echo "🚀 Bem-vindo ao Projeto DevOps AWS!"
echo ""

# Verificar se .env existe
if [ ! -f ".env" ]; then
    echo "📝 Configurando projeto pela primeira vez..."
    cp .env.example .env
    echo "✅ Arquivo .env criado"
    echo ""
    echo "⚠️  IMPORTANTE: Edite o arquivo .env antes de continuar"
    echo ""
    echo "Execute:"
    echo "  nano .env"
    echo ""
    echo "Depois execute:"
    echo "  ./validate.sh"
    exit 0
fi

echo "✅ Arquivo .env encontrado"
echo ""
echo "📋 Próximos passos:"
echo ""
echo "1️⃣  Validar ambiente:"
echo "   ./validate.sh"
echo ""
echo "2️⃣  Criar infraestrutura:"
echo "   ./deploy.sh"
echo ""
echo "3️⃣  Conectar ao banco:"
echo "   ./connect.sh"
echo ""
echo "💡 Ou use o Makefile:"
echo "   make help"
