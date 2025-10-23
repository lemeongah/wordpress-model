#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo ""
echo "🔍 AUDIT DES PERMISSIONS WORDPRESS"
echo "═══════════════════════════════════════════"
echo ""

if [ ! -d "wp" ]; then
    echo "❌ Dossier wp/ non trouvé"
    exit 1
fi

# Fonction pour vérifier le propriétaire
check_owner() {
    local path="$1"
    local expected="$2"
    local description="$3"

    if [ ! -e "$path" ]; then
        echo "⚠️  $description: $path (N'EXISTE PAS)"
        return 1
    fi

    local owner=$(ls -ld "$path" | awk '{print $3":"$4}')

    if [ "$owner" = "$expected" ]; then
        echo "✅ $description: $path ($owner)"
        return 0
    else
        echo "❌ $description: $path"
        echo "   Propriétaire actuel : $owner"
        echo "   Propriétaire attendu: $expected"
        return 1
    fi
}

# Fonction pour vérifier les permissions
check_perms() {
    local path="$1"
    local expected_dir="$2"
    local expected_file="$3"
    local description="$4"

    if [ ! -e "$path" ]; then
        return 0
    fi

    local count_dir=$(find "$path" -type d | wc -l)
    local count_file=$(find "$path" -type f | wc -l)

    if [ $count_dir -eq 0 ] && [ $count_file -eq 0 ]; then
        return 0
    fi

    echo "   📁 Permissions: $description"

    # Vérifier quelques fichiers/dossiers
    local bad_dirs=$(find "$path" -type d -not -perm 755 2>/dev/null | head -3)
    local bad_files=$(find "$path" -type f -not -perm 644 2>/dev/null | head -3)

    if [ -z "$bad_dirs" ] && [ -z "$bad_files" ]; then
        echo "      ✅ Toutes les permissions sont correctes"
    else
        if [ -n "$bad_dirs" ]; then
            echo "      ❌ Dossiers avec permissions incorrectes (!=755):"
            echo "$bad_dirs" | sed 's/^/         - /'
        fi
        if [ -n "$bad_files" ]; then
            echo "      ❌ Fichiers avec permissions incorrectes (!=644):"
            echo "$bad_files" | sed 's/^/         - /'
        fi
    fi
}

ERRORS=0

echo "📍 WORDPRESS"
echo "─────────────────────────────────────────"
check_owner "wp" "33:33" "Racine WordPress" || ((ERRORS++))
check_perms "wp" "755" "644" "wp/"

echo ""
echo "📍 WP-CONTENT"
echo "─────────────────────────────────────────"
check_owner "wp/wp-content" "33:33" "wp-content/" || ((ERRORS++))
check_perms "wp/wp-content" "755" "644" "wp-content/"

echo ""
echo "📍 THÈMES"
echo "─────────────────────────────────────────"
if [ -d "wp/wp-content/themes" ]; then
    check_owner "wp/wp-content/themes" "33:33" "Dossier themes" || ((ERRORS++))

    if [ -d "wp/wp-content/themes/generatepress" ]; then
        check_owner "wp/wp-content/themes/generatepress" "33:33" "GeneratePress" || ((ERRORS++))
    fi

    if [ -d "wp/wp-content/themes/generatepress-child" ]; then
        check_owner "wp/wp-content/themes/generatepress-child" "33:33" "GeneratePress Child" || ((ERRORS++))
    fi

    check_perms "wp/wp-content/themes" "755" "644" "themes/"
fi

echo ""
echo "📍 UPLOADS"
echo "─────────────────────────────────────────"
if [ -d "wp/wp-content/uploads" ]; then
    check_owner "wp/wp-content/uploads" "33:33" "Dossier uploads" || ((ERRORS++))
    check_perms "wp/wp-content/uploads" "755" "644" "uploads/"
fi

echo ""
echo "📍 PLUGINS"
echo "─────────────────────────────────────────"
if [ -d "wp/wp-content/plugins" ]; then
    check_owner "wp/wp-content/plugins" "33:33" "Dossier plugins" || ((ERRORS++))
    check_perms "wp/wp-content/plugins" "755" "644" "plugins/"
fi

echo ""
echo "📍 CONFIG FILES"
echo "─────────────────────────────────────────"
if [ -f "wp/wp-config.php" ]; then
    check_owner "wp/wp-config.php" "33:33" "wp-config.php" || ((ERRORS++))

    local wp_config_perms=$(stat -c %a "wp/wp-config.php" 2>/dev/null || stat -f %A "wp/wp-config.php" 2>/dev/null)
    if [ "$wp_config_perms" = "644" ]; then
        echo "   ✅ wp-config.php permissions: 644"
    else
        echo "   ⚠️  wp-config.php permissions: $wp_config_perms (recommandé: 644)"
    fi
fi

echo ""
echo "═══════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "✅ RÉSUMÉ: Toutes les permissions sont correctes !"
    echo ""
    exit 0
else
    echo "❌ RÉSUMÉ: $ERRORS erreur(s) de permission détectée(s)"
    echo ""
    echo "Pour corriger automatiquement, exécutez :"
    echo "  cd project && sudo fix_permissions.sh"
    echo ""
    exit 1
fi
