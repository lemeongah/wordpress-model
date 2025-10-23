# 🔐 Gestion des Permissions - Améliorations

## Résumé des Changements

Ce document décrit les améliorations apportées à la gestion des permissions dans le processus de déploiement WordPress.

### Problème Identifié

Le script `deploy-to-server.sh` avait un conflit de permissions entre deux utilisateurs :
- **`deploy`** : utilisateur qui fait les opérations Git et déploiement
- **`www-data` (uid:gid 33:33)** : utilisateur Docker exécutant WordPress

L'erreur `Permission denied` sur `.git/FETCH_HEAD` se produisait parce que :
1. Le repository Git était initialisé par l'utilisateur `gillesah`
2. Le déploiement s'exécutait en tant que `deploy`
3. Les permissions n'étaient pas correctement configurées pour permettre à `deploy` de manipuler Git

## Solutions Implémentées

### 1. **Fonction Centralisée de Gestion des Permissions** (`setup.sh`)

Ajout d'une fonction `fix_permissions()` pour standardiser la gestion des permissions :

```bash
fix_permissions() {
    local target_dir="$1"
    local description="${2:-Permission fix}"

    echo "🔐 $description : $target_dir"
    sudo chown -R 33:33 "$target_dir"
    sudo find "$target_dir" -type d -exec chmod 755 {} \;
    sudo find "$target_dir" -type f -exec chmod 644 {} \;
}
```

**Bénéfices:**
- ✅ Cohérence dans tout le script
- ✅ Réduit les doublons
- ✅ Facile à maintenir

### 2. **Améliorations de `setup.sh`**

#### Avant
- Code dupliqué pour les thèmes (lignes 161-226)
- Mix de `sudo chown -R $USER:$USER` et `33:33`
- Permissions incohérentes et surécrites
- Code peu lisible

#### Après
- ✅ Fonction `fix_permissions()` appelée systématiquement
- ✅ Propriétaire toujours `33:33` (www-data)
- ✅ Permissions toujours 755 (dossiers) / 644 (fichiers)
- ✅ Déduplication du code des thèmes
- ✅ Meilleure traçabilité avec un audit final

### 3. **Nouvelles Étape dans `deploy-to-server.sh`**

Ajout d'une **Étape 5.5** après l'installation WordPress :

```bash
# Étape 5.5 : Correction des permissions serveur

echo "🔐 Correction de la propriété et permissions de Git..."
sudo chown -R $SERVER_USER:$SERVER_USER .git
sudo chmod -R u+rwx .git

echo "🔐 Correction de la propriété et permissions du code..."
sudo chown -R $SERVER_USER:$SERVER_USER .

echo "🔐 Correction des permissions Docker..."
sudo chown -R 33:33 project/wp/
sudo find project/wp/ -type d -exec chmod 755 {} \;
sudo find project/wp/ -type f -exec chmod 644 {} \;
```

**Cela garantit:**
- ✅ `.git/` est propriété de `$SERVER_USER` (`deploy`) → permet les opérations Git
- ✅ Code source est propriété de `$SERVER_USER` → permet les mises à jour
- ✅ `wp/` est propriété de `33:33` (www-data) → Docker peut lire/écrire

### 4. **Scripts de Validation et Correction**

#### `scripts/check-permissions.sh` (NEW)
Audit complet des permissions avec rapport détaillé :

```bash
./scripts/check-permissions.sh
```

**Vérifie:**
- Propriétaire de chaque répertoire critique
- Permissions correctes (755/644)
- État de wp-config.php
- Génère un rapport coloré

#### `scripts/fix-permissions.sh` (NEW)
Correction manuelle des permissions si nécessaire :

```bash
./scripts/fix-permissions.sh
```

**Corrige automatiquement:**
- Propriétaire → 33:33 (www-data)
- Permissions → 755 (dossiers) / 644 (fichiers)
- Tous les répertoires critiques

## Architecture des Permissions

### Propriété des Fichiers

```
/var/www/bskyblog/
├── .git/                    → deploy:deploy (opérations Git)
├── project/
│   ├── docker-compose.yml   → deploy:deploy (config)
│   ├── .env                 → deploy:deploy (secrets)
│   ├── scripts/             → deploy:deploy (déploiement)
│   └── wp/                  → 33:33 (www-data - Docker)
│       ├── wp-config.php    → 33:33 (lectures WordPress)
│       ├── wp-content/      → 33:33 (uploads, plugins, themes)
│       └── index.php        → 33:33 (index WordPress)
```

### Permissions des Fichiers

| Type | Permissions | Propriétaire | Raison |
|------|-------------|-------------|--------|
| Dossiers | 755 | 33:33 | Docker peut lire/traverser |
| Fichiers PHP | 644 | 33:33 | Docker peut lire |
| wp-config.php | 644 | 33:33 | Sécurité (pas d'exécution) |
| .git/ | u+rwx | deploy | Opérations Git pour le déploiement |

## Workflow de Déploiement Continu

### Avant (❌ Problématique)
```
1. GitHub Actions pushes code
2. `deploy` user pulls via git
3. .git/ owned by 'gillesah' ← CONFLIT!
4. "Permission denied: .git/FETCH_HEAD"
5. Déploiement échoue
```

### Après (✅ Correct)
```
1. Étape 5.5 corrige les permissions
   - .git/ → deploy:deploy
   - wp/ → 33:33
2. GitHub Actions pushes code
3. `deploy` user can pull via git ✓
4. Docker containers run as www-data ✓
5. Déploiement réussit
```

## Configuration du Serveur (REQUIS)

**AVANT de lancer les déploiements avec GitHub Actions**, le serveur doit avoir une configuration sudoers pour permettre au user `deploy` d'exécuter certaines commandes sans mot de passe.

### Configuration initiale (UNE FOIS sur le serveur)

Exécutez ce script avec accès `sudo` sur le serveur de production :

```bash
# Télécharger le script
curl -s https://raw.githubusercontent.com/gillesah/wordpress-model/main/project/scripts/setup-sudoers.sh -o /tmp/setup-sudoers.sh
chmod +x /tmp/setup-sudoers.sh

# Exécuter
sudo /tmp/setup-sudoers.sh
```

Le script configure sudoers pour :
- `rm -rf .git` (nettoyage Git)
- `chown` / `chmod` (corrections de permissions)
- `docker compose` (opérations Docker)
- `mkdir` (création de répertoires)

Sans cette configuration, les déploiements échoueront avec `"sudo: a terminal is required"`.

## Intégration dans les Projets Existants

### Pour bskyblog (déjà déployé)

1. **D'abord**, configurer sudoers :
```bash
ssh root@193.203.169.72
/tmp/setup-sudoers.sh  # Exécuter sur le serveur
```

2. **Ensuite**, corriger les permissions existantes :
```bash
ssh deploy@193.203.169.72 << 'EOF'
cd /var/www/bskyblog
sudo rm -rf .git
git init
git remote add origin https://github.com/gillesah/bskyblog.git
git config user.email "deploy@server"
git config user.name "Deploy User"
git fetch origin main
git reset --hard origin/main
echo "✅ Repository Git réinitialisé"
EOF
```

### Pour les Nouveaux Sites

Les permissions seront correctes automatiquement grâce à :
1. `setup.sh` avec la nouvelle fonction `fix_permissions()`
2. `deploy-to-server.sh` avec l'Étape 5.5
3. **À condition que sudoers soit configuré** (voir section Configuration du Serveur)

## Tests de Validation

### Local
```bash
cd project
./scripts/setup.sh --reset        # Installation complète
./scripts/check-permissions.sh    # Vérifier les permissions
```

### Serveur
```bash
ssh deploy@193.203.169.72 << 'EOF'
cd /var/www/bskyblog/project
./scripts/check-permissions.sh
EOF
```

### GitHub Actions
```bash
git add .
git commit -m "Update: Improve permission handling"
git push origin main
# → Déploiement automatique via GitHub Actions
# → Étape 5.5 corrige les permissions
```

## Points Clés à Retenir

1. **Owner toujours 33:33 pour wp/** → Docker peut fonctionner
2. **Owner deploy pour .git/** → Git peut être mis à jour
3. **Permissions 755/644** → Lecture/exécution sûre et cohérente
4. **Audit avant et après** → Validation automatique

## Fichiers Modifiés

- ✅ `scripts/setup.sh` - Refactored avec fonction `fix_permissions()`
- ✅ `scripts/deploy-to-server.sh` - Ajout Étape 5.5
- ✅ `scripts/check-permissions.sh` - NEW (validation)
- ✅ `scripts/fix-permissions.sh` - NEW (correction manuelle)

## Support et Dépannage

### Erreur: "Permission denied: .git/FETCH_HEAD"
```bash
ssh deploy@SERVER "sudo chown -R deploy:deploy /var/www/FOLDER_NAME/.git && sudo chmod -R u+rwx /var/www/FOLDER_NAME/.git"
```

### Erreur: WordPress ne peut pas écrire les uploads
```bash
ssh deploy@SERVER "sudo chown -R 33:33 /var/www/FOLDER_NAME/project/wp && sudo find /var/www/FOLDER_NAME/project/wp -type d -exec chmod 755 {} \; && sudo find /var/www/FOLDER_NAME/project/wp -type f -exec chmod 644 {} \;"
```

### Vérifier les permissions actuelles
```bash
# Local
./scripts/check-permissions.sh

# Serveur
ssh deploy@SERVER "cd /var/www/FOLDER_NAME/project && ./scripts/check-permissions.sh"
```

---

**Version:** 1.0
**Date:** 2025-10-23
**Auteur:** Claude Code
