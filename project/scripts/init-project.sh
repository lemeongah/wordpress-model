#!/bin/bash
set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║       🚀 WordPress Site Deployment - Initialisation       ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Vérification qu'on est dans le bon dossier
if [ ! -f ".env.sample" ]; then
    log_error "Fichier .env.sample non trouvé !"
    log_error "Exécutez ce script depuis le dossier project/"
    exit 1
fi

# Charger la configuration serveur globale
WP_ENV_PATH="../../.env"
if [ ! -f "$WP_ENV_PATH" ]; then
    log_error "Fichier de configuration serveur manquant : $WP_ENV_PATH"
    log_error "Copiez ../../.env.sample vers ../../.env et configurez-le"
    exit 1
fi

log_info "Chargement de la configuration serveur depuis $WP_ENV_PATH"
source "$WP_ENV_PATH"

# Vérification des dépendances
log_info "Vérification des dépendances..."

if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) n'est pas installé. Installez-le avec: sudo apt install gh"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    log_error "Docker Compose n'est pas installé."
    exit 1
fi

log_success "Toutes les dépendances sont installées"

# ========================================
# ÉTAPE 1 : Copie du fichier .env depuis le template
# ========================================

echo ""
log_info "=== ÉTAPE 1/7 : Création du fichier .env depuis .env.sample ==="

if [ -f ".env" ]; then
    log_warning "Fichier .env existant trouvé"
    read -p "Écraser le fichier .env existant ? (o/N) : " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[oOyY]$ ]]; then
        log_info "Conservation du fichier .env existant"
    else
        cp .env.sample .env
        log_success "Fichier .env créé depuis .env.sample"
        log_warning "⚠️  IMPORTANT : Éditez maintenant le fichier .env pour configurer votre site"
        echo ""
        echo "Valeurs à modifier dans .env :"
        echo "  - COMPOSE_PROJECT_NAME (nom unique du projet)"
        echo "  - LOCAL_PORT (port Docker local, ex: 8089)"
        echo "  - ADMIN_PASSWORD (mot de passe admin WordPress)"
        echo "  - ADMIN_EMAIL (email admin)"
        echo "  - SITE_NAME (nom du site)"
        echo "  - SITE_COPYRIGHT (copyright footer)"
        echo "  - PROD_URL (URL de production, ex: https://monsite.com)"
        echo "  - FOLDER_NAME (nom du dossier sur le serveur)"
        echo "  - SERVER_PORT (port Docker sur le serveur)"
        echo ""
        read -p "Voulez-vous éditer .env maintenant ? (o/N) : " EDIT_NOW
        if [[ "$EDIT_NOW" =~ ^[oOyY]$ ]]; then
            ${EDITOR:-nano} .env
        else
            log_warning "N'oubliez pas d'éditer .env avant de continuer !"
            exit 0
        fi
    fi
else
    cp .env.sample .env
    log_success "Fichier .env créé depuis .env.sample"
    log_warning "⚠️  IMPORTANT : Éditez maintenant le fichier .env pour configurer votre site"
    echo ""
    echo "Valeurs à modifier dans .env :"
    echo "  - COMPOSE_PROJECT_NAME (nom unique du projet)"
    echo "  - LOCAL_PORT (port Docker local, ex: 8089)"
    echo "  - ADMIN_PASSWORD (mot de passe admin WordPress)"
    echo "  - ADMIN_EMAIL (email admin)"
    echo "  - SITE_NAME (nom du site)"
    echo "  - SITE_COPYRIGHT (copyright footer)"
    echo "  - PROD_URL (URL de production, ex: https://monsite.com)"
    echo "  - FOLDER_NAME (nom du dossier sur le serveur)"
    echo "  - SERVER_PORT (port Docker sur le serveur)"
    echo ""
    read -p "Voulez-vous éditer .env maintenant ? (o/N) : " EDIT_NOW
    if [[ "$EDIT_NOW" =~ ^[oOyY]$ ]]; then
        ${EDITOR:-nano} .env
    else
        log_warning "N'oubliez pas d'éditer .env avant de continuer !"
        exit 0
    fi
fi

# Charger le fichier .env du projet
source .env

# Validation des variables essentielles
if [ -z "$COMPOSE_PROJECT_NAME" ] || [ -z "$LOCAL_PORT" ] || [ -z "$PROD_URL" ]; then
    log_error "Variables manquantes dans .env (COMPOSE_PROJECT_NAME, LOCAL_PORT, PROD_URL)"
    exit 1
fi

# Extraire le nom de domaine depuis PROD_URL
DOMAIN=$(echo "$PROD_URL" | sed 's|https\?://||' | sed 's|/.*||')

echo ""
log_info "=== Configuration chargée ==="
echo "Projet         : $COMPOSE_PROJECT_NAME"
echo "Domaine        : $DOMAIN"
echo "Port local     : $LOCAL_PORT"
echo "Port serveur   : $SERVER_PORT"
echo "Email admin    : $ADMIN_EMAIL"
echo "Serveur        : $SERVER_USER@$SERVER_HOST"
echo ""

# ========================================
# ÉTAPE 2 : Installation locale WordPress
# ========================================

echo ""
log_info "=== ÉTAPE 2/7 : Installation WordPress en local ==="

if [ -f "./scripts/setup.sh" ]; then
    chmod +x ./scripts/setup.sh
    log_info "Lancement de l'installation locale... (cela peut prendre 3-5 minutes)"
    ./scripts/setup.sh
    log_success "Site WordPress installé localement sur http://localhost:$LOCAL_PORT"
else
    log_error "Script setup.sh non trouvé !"
    exit 1
fi

# ========================================
# ÉTAPE 3 : Initialisation Git
# ========================================

echo ""
log_info "=== ÉTAPE 3/7 : Initialisation Git ==="

cd ..  # Retour à la racine du projet

if [ ! -d ".git" ]; then
    git init
    git branch -m main
    log_success "Repository Git initialisé"
fi

# Créer .gitignore si absent
if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
.env
.env.prod
project/wp/
project/backups/*.sql.gz
.idea/
*.log
EOF
fi

git add .
git commit -m "Initial commit - $COMPOSE_PROJECT_NAME

Site WordPress initialisé avec :
- Domaine: $DOMAIN
- Configuration complète via .env
- Docker Compose prêt pour prod

🤖 Generated with init-project.sh" || log_warning "Pas de changements à commiter"

log_success "Git initialisé et premier commit créé"

# ========================================
# ÉTAPE 4 : Création du repository GitHub
# ========================================

echo ""
log_info "=== ÉTAPE 4/7 : Création du repository GitHub privé ==="

cd project
./scripts/create-github-repo.sh "$COMPOSE_PROJECT_NAME" "$SERVER_HOST" "$SERVER_USER" "$SSH_KEY_PATH" "$FOLDER_NAME"

if [ $? -ne 0 ]; then
    log_error "Échec de la création du repository GitHub"
    exit 1
fi

# ========================================
# ÉTAPE 5 : Déploiement sur le serveur
# ========================================

echo ""
log_info "=== ÉTAPE 5/7 : Déploiement sur le serveur ==="

./scripts/deploy-to-server.sh

if [ $? -ne 0 ]; then
    log_error "Échec du déploiement sur le serveur"
    exit 1
fi

# ========================================
# ÉTAPE 6 : Finalisation
# ========================================

echo ""
log_info "=== ÉTAPE 6/7 : Finalisation ==="

log_success "Synchronisation finale..."
cd ..
git pull origin main --rebase || log_warning "Aucune modification à synchroniser"

# Affichage du résumé
echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║              🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ! 🎉      ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
log_success "Site local     : http://localhost:$LOCAL_PORT"
log_success "Site production: https://$DOMAIN"
log_success "Admin WP       : https://$DOMAIN/wp-admin"
log_success "Repository     : https://github.com/$(gh api user -q .login)/$COMPOSE_PROJECT_NAME"
echo ""
log_info "Identifiants admin WordPress :"
echo "   - Email    : $ADMIN_EMAIL"
echo "   - Password : $ADMIN_PASSWORD"
echo ""
log_info "📝 Prochaines étapes :"
echo "   1. Testez le site en local : http://localhost:$LOCAL_PORT"
echo "   2. Testez le site en prod  : https://$DOMAIN"
echo "   3. Personnalisez le thème dans project/assets/"
echo "   4. Commitez et poussez : git add . && git commit -m 'Update' && git push"
echo ""
log_success "GitHub Actions déploiera automatiquement vos changements !"
echo ""
