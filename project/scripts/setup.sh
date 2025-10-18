#!/bin/bash
set -e

cd "$(dirname "$0")/.."

source .env

# Catégories par défaut si non définies dans .env
if [ -z "$CATEGORIES" ]; then
  CATEGORIES="social-trends|Tendances Social Media strategies|Stratégies pour Performer tools|Outils & IA"
fi

# Convertir la chaîne CATEGORIES en tableau
IFS=' ' read -ra CATEGORIES_ARRAY <<< "$CATEGORIES"
export WP_CLI_PHP_ARGS='-d memory_limit=512M'

ENVIRONMENT="${ENV:-$( [[ "$SITE_URL" == *"localhost"* ]] && echo "local" || echo "prod" )}"
echo "🌍 Environnement : $ENVIRONMENT"

RESET_DB=false

if [[ "$1" == "--reset" ]]; then
  RESET_DB=true
fi

echo "🧼 Nettoyage containers..."
docker compose down || true

if [ "$RESET_DB" = true ]; then
  echo "🧨 Suppression du volume de base de données (option --reset)..."
  VOLUME_NAME=$(docker volume ls --format '{{.Name}}' | grep "${COMPOSE_PROJECT_NAME:-$(basename "$PWD")}_db_data")
  if [[ -n "$VOLUME_NAME" ]]; then
    docker volume rm "$VOLUME_NAME" || true
  fi
else
  echo "✅ Volume base de données conservé."
fi
echo "🧼 Nettoyage des fichiers temporaires..."
sudo rm -rf wp tmp_wordpress generatepress.zip
mkdir -p wp tmp_wordpress

echo "📦 Téléchargement WordPress..."
wget https://wordpress.org/latest.tar.gz -O tmp_wordpress/latest.tar.gz
tar -xzf tmp_wordpress/latest.tar.gz --strip-components=1 -C wp
rm -rf tmp_wordpress

echo "🔐 Permissions initiales sur wp/"
sudo chown -R 33:33 wp
sudo find wp -type d -exec chmod 755 {} \;
sudo find wp -type f -exec chmod 644 {} \;

echo "📁 wp-content/upgrade"
sudo mkdir -p wp/wp-content/upgrade
sudo chown -R 33:33 wp/wp-content
sudo find wp/wp-content -type d -exec chmod 755 {} \;
sudo find wp/wp-content -type f -exec chmod 644 {} \;

echo "⚙️ Création de wp-config.php..."
cat << EOF | sudo tee wp/wp-config.php > /dev/null
<?php
define( 'DB_NAME', '$DB_NAME' );
define( 'DB_USER', '$DB_USER' );
define( 'DB_PASSWORD', '$DB_PASSWORD' );
define( 'DB_HOST', 'db:3306' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

define( 'AUTH_KEY',         '$(openssl rand -base64 32)' );
define( 'SECURE_AUTH_KEY',  '$(openssl rand -base64 32)' );
define( 'LOGGED_IN_KEY',    '$(openssl rand -base64 32)' );
define( 'NONCE_KEY',        '$(openssl rand -base64 32)' );
define( 'AUTH_SALT',        '$(openssl rand -base64 32)' );
define( 'SECURE_AUTH_SALT', '$(openssl rand -base64 32)' );
define( 'LOGGED_IN_SALT',   '$(openssl rand -base64 32)' );
define( 'NONCE_SALT',       '$(openssl rand -base64 32)' );

define( 'FS_METHOD', 'direct' );
\$table_prefix = 'wp_';
EOF

if [ "$ENVIRONMENT" = "local" ]; then
cat << EOF | sudo tee -a wp/wp-config.php > /dev/null
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'WP_HOME', '$SITE_URL' );
define( 'WP_SITEURL', '$SITE_URL' );
EOF
else
cat << EOF | sudo tee -a wp/wp-config.php > /dev/null
define( 'WP_DEBUG', false );
define( 'WP_DEBUG_DISPLAY', false );
define( 'WP_HOME', '$SITE_URL' );
define( 'WP_SITEURL', '$SITE_URL' );
define( 'FORCE_SSL_ADMIN', true );
define( 'FORCE_SSL_LOGIN', true );
if ( isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https' ) {
  \$_SERVER['HTTPS'] = 'on';
}
EOF
fi
echo "require_once ABSPATH . 'wp-settings.php';" | sudo tee -a wp/wp-config.php > /dev/null

echo "🚀 Lancement des containers..."
docker compose up -d
sleep 20

wpcli() { docker compose run --rm -v "$(pwd)/wp:/var/www/html" wpcli "$@"; }

echo "🛠️ Installation WordPress..."
wpcli core install \
  --url="$SITE_URL" \
  --title="$SITE_TITLE" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASSWORD" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email

echo "🔌 Plugins..."
wpcli plugin install seo-by-rank-math wpforms-lite wp-fastest-cache --activate
if [ "$ENVIRONMENT" = "prod" ]; then
  wpcli plugin install really-simple-ssl ssl-insecure-content-fixer
fi

echo "🚫 Désactivation des commentaires..."
wpcli option update default_comment_status closed
wpcli option update default_ping_status closed

# Ferme les commentaires sur tous les contenus existants
for ID in $(wpcli post list --format=ids); do
  wpcli post update "$ID" --comment_status=closed --ping_status=closed
done


echo "🌐 Installation de Polylang..."
wpcli plugin install polylang --activate

# Installer les langues système
wpcli language core install fr_FR
wpcli language core install en_US
wpcli language core activate fr_FR

# Mettre le site en français par défaut (WordPress général)
wpcli option update WPLANG fr_FR


echo "🎨 Installation du thème GeneratePress..."
wget -qO generatepress.zip https://downloads.wordpress.org/theme/generatepress.3.5.1.zip
echo "🔧 Correction des permissions du dossier themes..."
sudo mkdir -p wp/wp-content/themes
sudo chown -R $USER:$USER wp/wp-content/themes
sudo chmod -R 755 wp/wp-content/themes
unzip -q generatepress.zip -d wp/wp-content/themes/
rm generatepress.zip
sudo chown -R 33:33 wp/wp-content/themes/generatepress
sudo find wp/wp-content/themes/generatepress -type d -exec chmod 755 {} \;
sudo find wp/wp-content/themes/generatepress -type f -exec chmod 644 {} \;

echo "👶 Génération du thème enfant depuis assets/..."
CHILD_DIR="wp/wp-content/themes/generatepress-child"
rm -rf "$CHILD_DIR"
mkdir -p "$CHILD_DIR"

# Copier uniquement ce qui existe
cp ./assets/functions.php "$CHILD_DIR/functions.php" || echo "⚠️ functions.php non trouvé"
cp ./assets/footer.html "$CHILD_DIR/footer.html" || echo "ℹ️ footer.html pas obligatoire"

# Génération du style.css
cat << 'EOF' > "$CHILD_DIR/style.css"
/*
Theme Name: GeneratePress Child
Template: generatepress
Version: 1.0
*/
EOF

# Permissions
sudo chown -R 33:33 "$CHILD_DIR"
sudo find "$CHILD_DIR" -type d -exec chmod 755 {} \;
sudo find "$CHILD_DIR" -type f -exec chmod 644 {} \;

# Activation
wpcli theme activate generatepress-child


# Activer le thème enfant
wpcli theme activate generatepress-child
echo "👶 Thème enfant..."
mkdir -p wp/wp-content/themes/generatepress-child
sudo mkdir -p wp/wp-content/themes/generatepress-child
sudo chown -R $USER:$USER wp/wp-content/themes/generatepress-child
sudo chmod -R 755 wp/wp-content/themes/generatepress-child
echo "👶 Génération du thème enfant depuis assets/..."
CHILD_DIR="wp/wp-content/themes/generatepress-child"
rm -rf "$CHILD_DIR"
mkdir -p "$CHILD_DIR"

cp ./assets/functions.php "$CHILD_DIR/functions.php"
cp ./assets/style.css "$CHILD_DIR/style.css"
# cp ./assets/functions.php wp/wp-content/themes/generatepress-child/functions.php
cat << 'EOF' > wp/wp-content/themes/generatepress-child/style.css
/*
Theme Name: GeneratePress Child
Template: generatepress
Version: 1.0
*/
EOF
sudo chown -R 33:33 wp/wp-content/themes/generatepress-child
sudo mkdir -p wp/wp-content/themes/generatepress-child
sudo chown -R $USER:$USER wp/wp-content/themes/generatepress-child
sudo chmod -R 755 wp/wp-content/themes/generatepress-child
wpcli theme activate generatepress-child

echo "🖼️ Copie des assets..."
sudo mkdir -p wp/wp-content/uploads/custom/css
sudo chown -R $USER:$USER wp/wp-content/uploads/custom
cp -r ./assets/* wp/wp-content/uploads/custom/
cp ./assets/style.css wp/wp-content/uploads/custom/css/styles.css
sudo chown -R 33:33 wp/wp-content/uploads/custom
sudo find wp/wp-content/uploads/custom -type d -exec chmod 755 {} \;
sudo find wp/wp-content/uploads/custom -type f -exec chmod 644 {} \;
sudo chown -R 33:33 wp/wp-content/uploads/custom/css
sudo find wp/wp-content/uploads/custom/css -type d -exec chmod 755 {} \;
sudo find wp/wp-content/uploads/custom/css -type f -exec chmod 644 {} \;
echo "🔁 Permaliens..."
wpcli rewrite structure "/%postname%/"
wpcli rewrite flush --hard



echo "le logo"
echo "✅ Fix des permissions avant import du logo..."
sudo chown -R 33:33 wp/wp-content/uploads
sudo find wp/wp-content/uploads -type d -exec chmod 755 {} \;
sudo find wp/wp-content/uploads -type f -exec chmod 644 {} \;

# Ajouter le logo du site
LOGO_ID=$(wpcli media import /assets/logo.png --title="Logo" --porcelain)
wpcli theme mod set custom_logo "$LOGO_ID"

echo "📋 (Re)Création du menu principal avec les catégories..."
wpcli menu delete "Menu Principal" 2>/dev/null || true
wpcli menu create "Menu Principal"
wpcli menu location assign "Menu Principal" primary

# echo "🏷️ Création des catégories, pages et ajout au menu..."
# CATEGORIES=(
#   "ugc-parents|Parents"
#   "ugc-marques|Marques"
#   "ugc-enfants|Enfants"
# )
# echo "📋 (Re)Création du menu principal avec les catégories..."
# wpcli menu delete "Menu Principal" 2>/dev/null || true
# wpcli menu create "Menu Principal"
# wpcli menu location assign "Menu Principal" primary

# Création des catégories et des pages liées

for entry in "${CATEGORIES_ARRAY[@]}"; do
  IFS="|" read -r slug label <<< "$entry"

  wpcli term create category "$label" --slug="$slug" 2>/dev/null || true

  page_id=$(wpcli post create \
    --post_type=page \
    --post_status=publish \
    --post_title="$label" \
    --porcelain)

  wpcli post meta add "$page_id" _generate_hide_title true

  # Bloc WP avec filtre par catégorie
  block="<!-- wp:latest-posts {\
\"categories\":[\"$slug\"],\
\"displayPostContent\":true,\
\"excerptLength\":20,\
\"displayPostDate\":true,\
\"displayFeaturedImage\":true,\
\"featuredImageSizeSlug\":\"medium\"} /
\"layout\":{\"type\":\"grid\",\"columns\":3} } /-->"


  wpcli post update "$page_id" --post_content="$block"

  wpcli menu item add-post "Menu Principal" "$page_id" --title="$label"
done

# Création de la page d'accueil
echo "🏠 Création de la page d'accueil..."
HOME_ID=$(wpcli post create \
  --post_type=page \
  --post_status=publish \
  --post_title="Accueil" \
  --porcelain)

wpcli post meta add "$HOME_ID" _generate_hide_title true

home_block="<!-- wp:latest-posts {\
\"displayPostContent\":true,\
\"excerptLength\":20,\
\"displayPostDate\":true,\
\"displayFeaturedImage\":true,\
\"featuredImageSizeSlug\":\"medium\"} /
\"layout\":{\"type\":\"grid\",\"columns\":3} } /-->"

wpcli post update "$HOME_ID" --post_content="$home_block"

# Définir la page d'accueil statique
wpcli option update show_on_front page
wpcli option update page_on_front "$HOME_ID"




echo "🛠️ Fixe final des permissions..."
sudo chown -R 33:33 wp
sudo find wp -type d -exec chmod 755 {} \;
sudo find wp -type f -exec chmod 644 {} \;

echo "🔍 🔐 Audit des permissions finales (debug) :"
echo "➡️ wp-content permissions"
ls -l wp/wp-content | grep -E 'themes|uploads|upgrade'
echo "➡️ generatepress/"
ls -l wp/wp-content/themes/generatepress | head
echo "➡️ uploads/custom/"
ls -l wp/wp-content/uploads/custom | head

docker compose restart
echo "✅ Site opérationnel : $SITE_URL"
