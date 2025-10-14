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
# ÉTAPE 1 : Collecte des informations
# ========================================

echo ""
log_info "=== ÉTAPE 1/7 : Informations du projet ==="
echo ""

read -p "📝 Nom du projet (ex: myblog, sans espaces) : " PROJECT_NAME
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')

read -p "🌐 Nom de domaine (ex: myblog.com) : " DOMAIN

read -p "🔢 Port local Docker (ex: 8089) : " LOCAL_PORT

read -p "📧 Email administrateur : " ADMIN_EMAIL

read -p "🔐 Mot de passe admin WordPress : " ADMIN_PASSWORD

read -p "📝 Nom du site (affiché sur le site) : " SITE_NAME

read -p "©️  Nom pour le copyright (ex: Mon Entreprise) : " SITE_COPYRIGHT

echo ""
log_info "=== Informations du serveur ==="
echo ""

read -p "🖥️  IP ou hostname du serveur : " SERVER_HOST

read -p "👤 Utilisateur SSH : " SERVER_USER

read -p "🔑 Chemin vers la clé SSH (défaut: ~/.ssh/id_rsa) : " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa}

if [ ! -f "$SSH_KEY_PATH" ]; then
    log_error "Clé SSH non trouvée à $SSH_KEY_PATH"
    exit 1
fi

read -p "🔢 Port Docker sur le serveur (ex: 8089) : " SERVER_PORT

echo ""
log_info "=== Résumé de la configuration ==="
echo ""
echo "Projet         : $PROJECT_NAME"
echo "Domaine        : $DOMAIN"
echo "Port local     : $LOCAL_PORT"
echo "Port serveur   : $SERVER_PORT"
echo "Email admin    : $ADMIN_EMAIL"
echo "Serveur        : $SERVER_USER@$SERVER_HOST"
echo ""
read -p "Continuer avec ces informations ? (o/N) : " CONFIRM

if [[ ! "$CONFIRM" =~ ^[oOyY]$ ]]; then
    log_warning "Annulation de l'initialisation"
    exit 0
fi

# ========================================
# ÉTAPE 2 : Création du fichier .env
# ========================================

echo ""
log_info "=== ÉTAPE 2/7 : Création du fichier .env ==="

cat > .env << EOF
# ========================================
# CONFIGURATION DU SITE WORDPRESS
# ========================================

# === DOCKER & PROJET ===
COMPOSE_PROJECT_NAME=$PROJECT_NAME
LOCAL_PORT=$LOCAL_PORT

# === BASE DE DONNÉES ===
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_NAME=wordpress
DB_USER=wp
DB_PASSWORD=$(openssl rand -base64 16)

# === ADMIN WORDPRESS ===
ADMIN_USER=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_EMAIL=$ADMIN_EMAIL

# === INFORMATIONS DU SITE ===
SITE_NAME=$SITE_NAME
SITE_TITLE=$SITE_NAME
SITE_DESCRIPTION=Site WordPress $SITE_NAME
SITE_COPYRIGHT=$SITE_COPYRIGHT

# === URLs ===
# URL locale pour le développement
SITE_URL=http://localhost:$LOCAL_PORT

# URL de production
PROD_URL=https://$DOMAIN

# Nom du dossier sur le serveur de production
FOLDER_NAME=$PROJECT_NAME

# === SERVEUR (pour scripts de déploiement) ===
SERVER_HOST=$SERVER_HOST
SERVER_USER=$SERVER_USER
SERVER_PORT=$SERVER_PORT
SSH_KEY_PATH=$SSH_KEY_PATH
EOF

log_success "Fichier .env créé avec des mots de passe sécurisés"

# ========================================
# ÉTAPE 3 : Installation locale
# ========================================

echo ""
log_info "=== ÉTAPE 3/7 : Installation WordPress en local ==="

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
# ÉTAPE 4 : Initialisation Git
# ========================================

echo ""
log_info "=== ÉTAPE 4/7 : Initialisation Git ==="

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
git commit -m "Initial commit - $PROJECT_NAME

Site WordPress initialisé avec :
- Domaine: $DOMAIN
- Configuration complète via .env
- Docker Compose prêt pour prod

🤖 Generated with init-project.sh" || log_warning "Pas de changements à commiter"

log_success "Git initialisé et premier commit créé"

# ========================================
# ÉTAPE 5 : Création du repository GitHub
# ========================================

echo ""
log_info "=== ÉTAPE 5/7 : Création du repository GitHub privé ==="

cd project
./scripts/create-github-repo.sh "$PROJECT_NAME" "$SERVER_HOST" "$SERVER_USER" "$SSH_KEY_PATH" "$PROJECT_NAME"

if [ $? -ne 0 ]; then
    log_error "Échec de la création du repository GitHub"
    exit 1
fi

# ========================================
# ÉTAPE 6 : Déploiement sur le serveur
# ========================================

echo ""
log_info "=== ÉTAPE 6/7 : Déploiement sur le serveur ==="

./scripts/deploy-to-server.sh

if [ $? -ne 0 ]; then
    log_error "Échec du déploiement sur le serveur"
    exit 1
fi

# ========================================
# ÉTAPE 7 : Finalisation
# ========================================

echo ""
log_info "=== ÉTAPE 7/7 : Finalisation ==="

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
log_success "Repository     : https://github.com/$(gh api user -q .login)/$PROJECT_NAME"
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
