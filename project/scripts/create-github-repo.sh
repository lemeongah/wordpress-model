#!/bin/bash
set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Paramètres
PROJECT_NAME=$1
SERVER_HOST=$2
SERVER_USER=$3
SSH_KEY_PATH=$4

if [ -z "$PROJECT_NAME" ] || [ -z "$SERVER_HOST" ] || [ -z "$SERVER_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    log_error "Usage: $0 <project_name> <server_host> <server_user> <ssh_key_path>"
    exit 1
fi

log_info "Création du repository GitHub : $PROJECT_NAME"

# Vérifier si on est déjà dans un repo avec un remote
cd ..  # Retour à la racine du projet

if git remote get-url origin &> /dev/null; then
    log_warning "Un remote 'origin' existe déjà"
    REPO_URL=$(git remote get-url origin)
    log_info "Repository existant : $REPO_URL"
else
    # Créer le repository GitHub
    log_info "Création du repository GitHub privé..."

    gh repo create "$PROJECT_NAME" \
        --private \
        --source=. \
        --remote=origin \
        --description "Site WordPress - $PROJECT_NAME - Déploiement automatisé" \
        --push

    if [ $? -eq 0 ]; then
        log_success "Repository GitHub créé et code poussé"
    else
        log_error "Échec de la création du repository"
        exit 1
    fi
fi

# Configurer les secrets GitHub Actions
log_info "Configuration des secrets GitHub Actions..."

# Secret 1: SERVER_HOST
echo "$SERVER_HOST" | gh secret set SERVER_HOST
log_success "Secret SERVER_HOST configuré"

# Secret 2: SERVER_USER
echo "$SERVER_USER" | gh secret set SERVER_USER
log_success "Secret SERVER_USER configuré"

# Secret 3: SERVER_SSH_KEY (contenu de la clé privée)
if [ -f "$SSH_KEY_PATH" ]; then
    gh secret set SERVER_SSH_KEY < "$SSH_KEY_PATH"
    log_success "Secret SERVER_SSH_KEY configuré"
else
    log_error "Clé SSH non trouvée à $SSH_KEY_PATH"
    exit 1
fi

# Vérifier les secrets
log_info "Vérification des secrets configurés..."
gh secret list

log_success "Repository GitHub configuré avec succès !"
echo ""
log_info "URL du repository : $(gh repo view --json url -q .url)"
echo ""

cd project  # Retour au dossier project
