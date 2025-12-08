# Feature Specification: Press SaaS Platform

**Feature Branch**: `001-press-saas-platform`  
**Created**: 2025-12-07  
**Status**: Draft  
**Input**: Infrastructure Docker pour déployer et gérer des sites Frappe/ERPNext avec PostgreSQL 16, multi-tenancy, SSO Keycloak, reverse proxy Traefik, et stockage S3 MinIO.

---

## Clarifications

### Session 2025-12-08

- Q: Que doit faire le système si Keycloak est indisponible lors d'une tentative de connexion SSO ? → A: Fallback automatique vers authentification locale Frappe (email/password).
- Q: Quel est le modèle de tenancy pour les sites (DB) ? → A: Option B — schéma par site sur un seul serveur PostgreSQL (un serveur Postgres, un schéma par site).
- Q: Quelle est la fréquence et la rétention des backups ? → A: Daily backups, retained 30 days (prune older backups).


## User Scenarios & Testing

### User Story 1 - Démarrer l'infrastructure complète (Priority: P1)

En tant qu'administrateur DevOps, je veux lancer toute l'infrastructure avec une seule commande `docker compose up -d` pour avoir un environnement Press fonctionnel.

**Why this priority**: C'est la fondation - sans infrastructure, rien ne fonctionne.

**Independent Test**: Exécuter `docker compose up -d` et vérifier que tous les containers sont "healthy".

**Acceptance Scenarios**:

1. **Given** un fichier `.env` configuré, **When** `docker compose up -d`, **Then** tous les containers démarrent sans erreur
2. **Given** les containers démarrés, **When** `docker compose ps`, **Then** tous les services sont "healthy" en moins de 2 minutes
3. **Given** l'infrastructure UP, **When** accès à `https://press.localhost:48543`, **Then** la page d'accueil Press s'affiche

---

### User Story 2 - Créer un nouveau site Frappe (Priority: P1)

En tant qu'administrateur, je veux créer un nouveau site Frappe via l'interface Press pour qu'un client puisse utiliser ERPNext.

**Why this priority**: C'est la fonctionnalité core de Press - créer des sites.

**Independent Test**: Créer un site via UI et accéder à son URL.

**Acceptance Scenarios**:

1. **Given** l'utilisateur connecté à Press, **When** il clique "Create Site", **Then** un formulaire de création s'affiche
2. **Given** le formulaire rempli (nom, apps), **When** soumission, **Then** le site est créé avec PostgreSQL 16
3. **Given** le site créé, **When** accès à `https://{site}.localhost:48543`, **Then** la page de login Frappe s'affiche

---

### User Story 3 - Authentification SSO via Keycloak (Priority: P2)

En tant qu'utilisateur, je veux me connecter à Press via Keycloak SSO pour une authentification centralisée, et pouvoir me connecter via email/password local si Keycloak est indisponible.

**Why this priority**: Sécurité et expérience utilisateur unifiée, mais résilience en cas de panne SSO.

**Independent Test**: Login via Keycloak et accès automatique à Press. Simuler une panne Keycloak et tester le fallback local.

**Acceptance Scenarios**:

1. **Given** Keycloak configuré, **When** clic "Login with SSO", **Then** redirection vers Keycloak
2. **Given** credentials valides sur Keycloak, **When** authentification, **Then** retour automatique sur Press connecté
3. **Given** session expirée, **When** accès à Press, **Then** redirection vers Keycloak pour re-auth
4. **Given** Keycloak indisponible, **When** accès à Press, **Then** affichage du formulaire de login local Frappe (email/password)

---

### User Story 4 - Stockage S3 pour les fichiers (Priority: P2)

En tant que système, je veux stocker les fichiers uploadés sur MinIO S3 pour une gestion centralisée et scalable.

**Why this priority**: Performance et scalabilité du stockage.

**Independent Test**: Upload un fichier et vérifier sa présence dans MinIO.

**Acceptance Scenarios**:

1. **Given** MinIO configuré, **When** upload d'un fichier dans Frappe, **Then** le fichier est stocké dans le bucket MinIO
2. **Given** un fichier stocké, **When** téléchargement, **Then** le fichier est servi depuis MinIO
3. **Given** MinIO indisponible, **When** upload, **Then** erreur explicite sans perte de données

---

### User Story 5 - Backup automatique des sites (Priority: P3)

En tant qu'administrateur, je veux des backups automatiques quotidiens pour protéger les données clients.

**Why this priority**: Résilience et conformité, mais pas bloquant pour MVP.

**Independent Test**: Déclencher un backup manuel et restaurer.

**Acceptance Scenarios**:

1. **Given** un site existant, **When** clic "Backup Now", **Then** backup créé dans MinIO
2. **Given** backup existant, **When** clic "Restore", **Then** le site est restauré à l'état du backup
3. **Given** schedule configuré, **When** heure du backup, **Then** backup automatique sans intervention
4. **Given** schedule configuré (daily), **When** backup runs, **Then** daily backups are saved and backups older than 30 days are pruned automatically
5. **Given** un site supprimé (soft-delete), **When** le restore est demandé dans la période de rétention, **Then** le site est restauré depuis le backup correspondant
6. **Given** un site supprimé depuis plus de 30 jours, **When** l'administrateur tente la restauration, **Then** la restauration échoue (entité supprimée définitivement)

---

### Edge Cases

- Que se passe-t-il si PostgreSQL est indisponible au démarrage ?
- Comment gérer un site dont le nom existe déjà ?
- Que faire si MinIO est plein (quota atteint) ?
- Que faire si Keycloak est indisponible ? → Fallback automatique vers authentification locale Frappe (email/password)
- Gestion des sites orphelins (container supprimé manuellement) ?
- Suppression de site: soft-delete (marquer supprimé), conserver données 30 jours; suppression permanente après 30 jours si non restauré

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST démarrer via `docker compose up -d` sans configuration manuelle additionnelle
- **FR-002**: System MUST utiliser PostgreSQL 16 comme base de données (pas MariaDB)
- **FR-003**: System MUST exposer Press sur le port HTTPS 48543 via Traefik
- **FR-004**: System MUST permettre la création de sites Frappe via l'interface Press
- **FR-005**: System MUST stocker les fichiers uploadés dans MinIO S3
- **FR-006**: System MUST supporter l'authentification via Keycloak OAuth2/OIDC
- **FR-007**: System MUST utiliser le préfixe `fcs-press-*` pour tous les containers
- **FR-008**: System MUST exposer les services uniquement dans la plage de ports 48510-49800
- **FR-009**: System MUST inclure des healthchecks pour tous les services critiques
- **FR-010**: System MUST supporter les backups vers MinIO S3
- **FR-011**: System MUST permettre un fallback automatique vers l'authentification locale Frappe (email/password) si Keycloak est indisponible
- **FR-012**: System MUST implementer une stratégie de tenancy PostgreSQL: un seul serveur PostgreSQL, un schéma distinct par site (schema-per-site)
- **FR-013**: Backups MUST être possible au niveau du schéma (par-site) et restaurables indépendamment
- **FR-014**: System MUST implementer une soft-delete lifecycle for sites (mark deleted, 30-day retention) and support restore within that retention window
- **FR-015**: Backups MUST be scheduled daily and retained for 30 days (automatic pruning of older backups)

### Non-Functional Requirements

- **NFR-001**: Tous les containers MUST démarrer en moins de 2 minutes
- **NFR-002**: L'infrastructure MUST supporter au moins 10 sites simultanés
- **NFR-003**: Les logs MUST être accessibles via `docker compose logs`
- **NFR-004**: La configuration MUST être externalisée via `.env`
- **NFR-005**: Les secrets MUST être gérés via Docker secrets ou variables d'environnement

### Key Entities

- **Site**: Instance Frappe/ERPNext avec son propre domaine, DB, et configuration
- **Bench**: Environnement d'exécution Frappe contenant les apps installées
- **Server**: Hôte Docker exécutant l'infrastructure Press
- **Backup**: Snapshot d'un site (DB + fichiers) stocké dans S3

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: `docker compose up -d` démarre tous les services sans erreur en moins de 2 minutes
- **SC-002**: Un nouveau site Frappe peut être créé via Press UI en moins de 5 minutes
- **SC-003**: L'authentification SSO Keycloak fonctionne sans configuration manuelle côté utilisateur
- **SC-004**: Les fichiers uploadés sont stockés dans MinIO et accessibles
- **SC-005**: Un backup complet peut être créé et restauré sans perte de données
- **SC-006**: Daily backups are scheduled and retained for 30 days (older backups pruned automatically)

---

## Technical Constraints (from Constitution)

| Composant | Version/Spec |
|-----------|--------------|
| Frappe Framework | v16 (version-16 branch) |
| PostgreSQL | 16.x |
| Redis | 7.x |
| Traefik | 3.x |
| Keycloak | 22.x+ |
| MinIO | Latest |
| Container Prefix | `fcs-press-*` |
| Port Range | 48510-49800 |

### Port Allocation

| Service | Port |
|---------|------|
| Redis Queue | 48511 |
| Redis Cache | 48579 |
| Traefik HTTP | 48580 |
| Traefik HTTPS | 48543 |
| MinIO API | 48590 |
| MinIO Console | 48591 |
| PostgreSQL | 48532 |
| Keycloak | 48580 (via Traefik) |
