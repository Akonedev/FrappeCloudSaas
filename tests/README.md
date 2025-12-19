# Press SaaS Platform - Test Suite

Suite complète de tests pour vérifier l'implémentation de la plateforme Press SaaS avec Frappe v16 + PostgreSQL 16.

## 📋 Structure des tests

```
tests/
├── integration/        # Tests d'intégration des services
│   └── test_services.py
├── e2e/               # Tests end-to-end HTTP
│   └── test_http_access.py
├── security/          # Tests de sécurité
│   └── test_security.py
├── performance/       # Tests de performance
│   └── test_performance.py
├── run_all_tests.sh   # Script pour exécuter tous les tests
└── README.md          # Ce fichier
```

## 🚀 Exécution rapide

### Lancer tous les tests
```bash
./tests/run_all_tests.sh
```

### Lancer un test spécifique

```bash
# Tests d'intégration
python3 tests/integration/test_services.py

# Tests E2E
python3 tests/e2e/test_http_access.py

# Tests de sécurité
python3 tests/security/test_security.py

# Tests de performance
python3 tests/performance/test_performance.py
```

## 📊 Suites de tests

### 1. Tests d'intégration (`integration/test_services.py`)

**Objectif** : Vérifier que tous les services Docker/Podman fonctionnent correctement.

**Tests inclus** :
- ✅ État des containers (running/stopped)
- ✅ Bindings de ports (48510, 48511, 48532, 48580)
- ✅ Connectivité réseau entre services
- ✅ Connexion PostgreSQL depuis le backend
- ✅ Connexion Redis Cache et Queue
- ✅ Existence du site Frappe `press.localhost`

**Commande** :
```bash
python3 tests/integration/test_services.py
```

**Résultats attendus** :
- 9 services en cours d'exécution
- Tous les ports correctement exposés
- Connexions base de données fonctionnelles

---

### 2. Tests End-to-End (`e2e/test_http_access.py`)

**Objectif** : Vérifier le flux HTTP complet et les redirections Nginx.

**Tests inclus** :
- ✅ Redirection 301 : `localhost:48580` → `press.localhost:48580`
- ✅ Accès direct à `press.localhost:48580` (HTTP 200)
- ✅ Détection du contenu Frappe/ERPNext
- ✅ Configuration Nginx (fichier `localhost-redirect.conf`)
- ✅ Headers de sécurité HTTP (X-Frame-Options, X-Content-Type-Options)

**Commande** :
```bash
python3 tests/e2e/test_http_access.py
```

**Résultats attendus** :
- Redirection automatique fonctionnelle
- Page de login Frappe accessible
- Headers de sécurité présents

---

### 3. Tests de sécurité (`security/test_security.py`)

**Objectif** : Vérifier les configurations de sécurité et la gestion des secrets.

**Tests inclus** :
- ✅ Fichier `.env` dans `.gitignore`
- ✅ Permissions du fichier `.env` (600 ou 640)
- ✅ Absence de secrets dans l'historique Git
- ✅ Pas de mots de passe par défaut
- ✅ Utilisation de variables d'environnement dans Docker Compose
- ✅ Documentation des ports exposés
- ✅ Isolation réseau (réseau dédié `fcs-press-network`)

**Commande** :
```bash
python3 tests/security/test_security.py
```

**Résultats attendus** :
- Aucun secret hardcodé
- Configuration sécurisée des fichiers sensibles
- Isolation réseau complète

---

### 4. Tests de performance (`performance/test_performance.py`)

**Objectif** : Mesurer les temps de réponse et la performance sous charge.

**Tests inclus** :
- ✅ Temps de réponse HTTP (moyenne, min, max)
- ✅ Performance de la redirection Nginx
- ✅ Gestion de requêtes concurrentes (10 requêtes simultanées)
- ✅ Headers de cache (Cache-Control, ETag)

**Commande** :
```bash
python3 tests/performance/test_performance.py
```

**Résultats attendus** :
- Temps de réponse < 2000ms (moyenne)
- Redirection < 100ms
- 90%+ de succès sur requêtes concurrentes

---

## 🎯 Critères de succès

Pour que la plateforme soit considérée comme prête pour la production :

| Catégorie | Taux de réussite minimum |
|-----------|--------------------------|
| **Intégration** | 90% |
| **End-to-End** | 95% |
| **Sécurité** | 100% (aucun échec critique) |
| **Performance** | 80% |

## 📝 Interprétation des résultats

### Codes couleur

- 🟢 **Vert (✓)** : Test réussi
- 🟡 **Jaune (⚠)** : Avertissement (non critique)
- 🔴 **Rouge (✗)** : Test échoué (à corriger)

### Exemples de sortie

```bash
🔍 Testing PostgreSQL 16...
  ✓ Container fcs-press-db is running
  ✓ PostgreSQL 16 health check passed
  ✓ Port 48532 is properly bound
```

## 🔧 Prérequis

**Avant de lancer les tests** :

1. **Services démarrés** :
   ```bash
   podman compose \
     -f compose.yaml \
     -f overrides/compose.postgres.yaml \
     -f overrides/compose.redis.yaml \
     -f overrides/compose.noproxy.yaml \
     -f overrides/compose.networks.yaml \
     up -d
   ```

2. **Site Frappe créé** :
   ```bash
   podman exec frappe_docker_git-backend-1 bench new-site press.localhost \
     --admin-password admin \
     --db-type postgres \
     --db-host fcs-press-db \
     --install-app erpnext
   ```

3. **Python 3** installé :
   ```bash
   python3 --version  # Python 3.6+
   ```

## 🐛 Dépannage

### Problème : Tests échouent avec "Connection refused"

**Solution** :
```bash
# Vérifier que les services sont démarrés
podman ps | grep fcs-press

# Redémarrer les services si nécessaire
podman compose up -d
```

### Problème : "Site press.localhost not found"

**Solution** :
```bash
# Créer le site Frappe
podman exec frappe_docker_git-backend-1 bench new-site press.localhost \
  --admin-password admin \
  --db-type postgres \
  --db-host fcs-press-db
```

### Problème : Tests de sécurité échouent sur "Secrets in git"

**Solution** :
Les résultats peuvent contenir des faux positifs (mot "token" dans la documentation).
Vérifier manuellement les fichiers listés.

## 📊 Rapport de tests

Le script `run_all_tests.sh` génère un rapport final :

```
╔════════════════════════════════════════════════════════════╗
║                    FINAL TEST REPORT                       ║
╚════════════════════════════════════════════════════════════╝

Total Test Suites:  4
Passed:            3
Failed:            1

Success Rate:       75%
```

## 🔄 CI/CD

Ces tests peuvent être intégrés dans un pipeline CI/CD :

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: |
          chmod +x tests/run_all_tests.sh
          ./tests/run_all_tests.sh
```

## 📚 Documentation

Pour plus d'informations sur la plateforme :
- [README.md](../README.md) - Vue d'ensemble
- [quickstart.md](../specs/001-press-saas-platform/quickstart.md) - Guide de démarrage
- [spec.md](../specs/001-press-saas-platform/spec.md) - Spécifications complètes

---

**Version** : 1.0.0
**Date** : Décembre 2025
**Mainteneur** : @akone
