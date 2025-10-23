#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo ""
echo "🔧 CORRECTION DES PERMISSIONS WORDPRESS"
echo "═══════════════════════════════════════════"
echo ""

if [ ! -d "wp" ]; then
    echo "❌ Dossier wp/ non trouvé"
    exit 1
fi

# Vérifier qu'on a les droits sudo
if ! sudo -n true 2>/dev/null; then
    echo "⚠️  Ce script nécessite les droits sudo"
    exit 1
fi

fix_permissions() {
    local target_dir="$1"
    local description="${2:-Permission fix}"

    if [ ! -d "$target_dir" ]; then
        echo "⚠️  $description: $target_dir (N'existe pas)"
        return 0
    fi

    echo "🔐 $description : $target_dir"
    sudo chown -R 33:33 "$target_dir"
    sudo find "$target_dir" -type d -exec chmod 755 {} \;
    sudo find "$target_dir" -type f -exec chmod 644 {} \;
    echo "   ✅ Permissions corrigées"
}

echo "⏳ Correction des permissions..."
echo ""

fix_permissions "wp" "WordPress"
fix_permissions "wp/wp-content" "wp-content"
fix_permissions "wp/wp-content/themes" "Thèmes"
fix_permissions "wp/wp-content/plugins" "Plugins"
fix_permissions "wp/wp-content/uploads" "Uploads"

echo ""
echo "═══════════════════════════════════════════"
echo "✅ Permissions corrigées avec succès !"
echo ""
echo "Pour vérifier, exécutez :"
echo "  ./scripts/check-permissions.sh"
echo ""
