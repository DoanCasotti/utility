# 🚀 Como Subir o Projeto para o GitHub

## 📋 Passo a Passo

### 1️⃣ Criar Repositório no GitHub

1. Acesse: https://github.com/new
2. Nome do repositório: `aws-devops-infrastructure` (ou outro nome)
3. Descrição: `Infraestrutura AWS automatizada com RDS privado e Bastion via SSM`
4. **NÃO** marque "Initialize with README" (já temos um)
5. Clique em **Create repository**

---

### 2️⃣ Inicializar Git Local

No terminal, dentro da pasta do projeto:

```bash
# Inicializar repositório
git init

# Adicionar todos os arquivos
git add .

# Primeiro commit
git commit -m "Initial commit: AWS DevOps Infrastructure"
```

---

### 3️⃣ Conectar ao GitHub

Substitua `SEU_USUARIO` e `NOME_DO_REPO` pelos seus dados:

```bash
# Adicionar remote
git remote add origin https://github.com/SEU_USUARIO/NOME_DO_REPO.git

# Ou com SSH (se configurado):
git remote add origin git@github.com:SEU_USUARIO/NOME_DO_REPO.git

# Enviar para o GitHub
git branch -M main
git push -u origin main
```

---

### 4️⃣ Verificar .gitignore

O arquivo `.gitignore` já está configurado para proteger:
- `.env` (credenciais)
- `*.pem` (chaves SSH)
- `*.key` (chaves privadas)
- `backups/` (backups locais)
- `*.log` (logs)

---

## 🔒 Segurança

### ⚠️ NUNCA commite:
- ❌ Arquivo `.env` com credenciais
- ❌ Chaves privadas (*.pem, *.key)
- ❌ Access Keys da AWS
- ❌ Senhas de banco de dados

### ✅ Pode commitar:
- ✅ `.env.example` (template sem credenciais)
- ✅ Scripts (.sh)
- ✅ Documentação (README.md)
- ✅ Configurações (Makefile, .gitignore)

---

## 📝 Comandos Git Úteis

### Verificar status
```bash
git status
```

### Adicionar mudanças
```bash
git add .
git commit -m "Descrição da mudança"
git push
```

### Ver histórico
```bash
git log --oneline
```

### Criar branch
```bash
git checkout -b feature/nova-funcionalidade
```

---

## 🎯 Exemplo Completo

```bash
# 1. Inicializar
cd "/mnt/e/AWS-CURSOS/Projeto Devops"
git init

# 2. Adicionar arquivos
git add .

# 3. Primeiro commit
git commit -m "feat: Initial commit - AWS DevOps Infrastructure

- Infraestrutura completa VPC + Bastion + RDS
- Scripts de deploy, connect e destroy
- Validação de ambiente
- Estimativa de custos
- Documentação completa"

# 4. Conectar ao GitHub (substitua SEU_USUARIO e REPO)
git remote add origin https://github.com/SEU_USUARIO/aws-devops-infrastructure.git

# 5. Enviar
git branch -M main
git push -u origin main
```

---

## 🌟 Melhorar o README para GitHub

Adicione badges no topo do README.md:

```markdown
# 🚀 Projeto DevOps - Infraestrutura AWS Automatizada

![AWS](https://img.shields.io/badge/AWS-Cloud-orange)
![Bash](https://img.shields.io/badge/Bash-Script-green)
![License](https://img.shields.io/badge/License-MIT-blue)

Infraestrutura completa para RDS PostgreSQL privado...
```

---

## 🔄 Atualizações Futuras

```bash
# Fazer mudanças nos arquivos
nano deploy.sh

# Adicionar e commitar
git add deploy.sh
git commit -m "fix: Corrigir validação de senha no deploy"

# Enviar para GitHub
git push
```

---

## 🆘 Problemas Comuns

### Erro: "remote origin already exists"
```bash
git remote remove origin
git remote add origin https://github.com/SEU_USUARIO/REPO.git
```

### Erro: "failed to push"
```bash
git pull origin main --rebase
git push
```

### Commitou .env por engano?
```bash
# Remover do Git mas manter local
git rm --cached .env
git commit -m "Remove .env from repository"
git push
```
