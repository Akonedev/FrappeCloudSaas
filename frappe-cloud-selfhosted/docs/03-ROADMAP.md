# 🗺️ Roadmap

## Vision

Créer une plateforme SaaS self-hosted de niveau entreprise permettant de déployer 
et gérer des instances Frappe/ERPNext de manière automatisée.

---

## Version 1.0 - MVP (Q4 2024)

### 🎯 Objectif
Plateforme fonctionnelle avec workflow complet d'inscription à site opérationnel.

### Fonctionnalités

#### Core Platform
- [x] Infrastructure Docker complète
- [x] Traefik avec SSL wildcard automatique
- [x] MariaDB + Redis cluster ready
- [x] MinIO pour stockage S3

#### Press Integration
- [ ] Press v16 avec patches self-hosted
- [ ] Agent intégré au conteneur
- [ ] Création site automatique
- [ ] Installation apps automatique

#### Billing (Lago)
- [ ] Plans d'abonnement (Starter, Business, Enterprise)
- [ ] Checkout flow
- [ ] Invoices automatiques
- [ ] Webhooks → provisioning

#### Dashboard
- [ ] Inscription utilisateur
- [ ] Liste des sites
- [ ] Gestion basique site

### Métriques de Succès
- Création site < 5 minutes
- Uptime 99.5%
- 0 intervention manuelle pour création site

---

## Version 1.1 - Enhanced (Q1 2025)

### 🎯 Objectif
Améliorer l'expérience utilisateur et la fiabilité.

### Fonctionnalités

#### User Experience
- [ ] Dashboard redesign
- [ ] Onboarding wizard
- [ ] Documentation in-app
- [ ] Support chat intégré

#### Apps Marketplace
- [ ] Catalogue d'apps
- [ ] Installation one-click
- [ ] Apps tierces (partners)
- [ ] Reviews/Ratings

#### Operations
- [ ] Backup/Restore self-service
- [ ] Logs accessibles
- [ ] Métriques site (CPU, RAM, Storage)
- [ ] Alertes personnalisées

#### Keycloak SSO
- [ ] Login unifié
- [ ] Social login (Google, GitHub, Microsoft)
- [ ] 2FA/MFA
- [ ] Gestion équipes

### Métriques de Succès
- NPS > 40
- Self-service rate > 80%
- Support tickets < 10/semaine

---

## Version 1.2 - Scale (Q2 2025)

### 🎯 Objectif
Supporter des charges de travail importantes.

### Fonctionnalités

#### Multi-Tenant Avancé
- [ ] Isolation ressources par tenant
- [ ] Quotas par plan
- [ ] Fair usage policy
- [ ] Throttling automatique

#### High Availability
- [ ] MariaDB Galera cluster
- [ ] Redis Sentinel
- [ ] Load balancing Traefik
- [ ] Multi-region (optionnel)

#### Monitoring Pro
- [ ] Prometheus + Grafana
- [ ] Loki pour logs
- [ ] Alertmanager
- [ ] SLA dashboards

#### API Publique
- [ ] REST API complète
- [ ] Webhooks sortants
- [ ] SDK (Python, JavaScript)
- [ ] Rate limiting

### Métriques de Succès
- Support 500+ sites
- Latence P99 < 500ms
- Recovery time < 5 minutes

---

## Version 2.0 - Enterprise (Q3-Q4 2025)

### 🎯 Objectif
Fonctionnalités enterprise-grade.

### Fonctionnalités

#### Compliance
- [ ] GDPR tools
- [ ] Audit logs complets
- [ ] Data export
- [ ] Right to be forgotten

#### White Label
- [ ] Branding custom
- [ ] Domaine custom
- [ ] Email templates custom
- [ ] Theme builder

#### Advanced Billing
- [ ] Usage-based pricing
- [ ] Custom pricing
- [ ] Multiple currencies
- [ ] Tax management

#### Integrations
- [ ] Stripe direct
- [ ] PayPal
- [ ] Accounting (Xero, QBO)
- [ ] CRM sync

#### Multi-Cloud
- [ ] Deploy sur AWS
- [ ] Deploy sur GCP
- [ ] Deploy sur Azure
- [ ] Hybrid cloud

### Métriques de Succès
- Certification SOC2
- Enterprise clients > 10
- ARR > 100k€

---

## Backlog Futur

### Idées à Explorer

| Priorité | Fonctionnalité | Effort | Impact |
|----------|----------------|--------|--------|
| Haute | AI Assistant | L | H |
| Haute | Mobile App | M | H |
| Medium | Kubernetes deploy | L | M |
| Medium | Terraform provider | M | M |
| Basse | Blockchain billing | L | L |
| Basse | Edge deployments | XL | M |

### Technical Debt

- [ ] Migration vers Frappe v17 (quand stable)
- [ ] Refactor patches en PR upstream
- [ ] Tests E2E complets
- [ ] Performance optimization

---

## Timeline Visuelle

```
2024 Q4          2025 Q1          2025 Q2          2025 Q3-Q4
   │                │                │                │
   ▼                ▼                ▼                ▼
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  v1.0    │   │  v1.1    │   │  v1.2    │   │  v2.0    │
│  MVP     │──▶│ Enhanced │──▶│  Scale   │──▶│Enterprise│
│          │   │          │   │          │   │          │
│ • Core   │   │ • UX     │   │ • HA     │   │ • Comply │
│ • Press  │   │ • Apps   │   │ • Monitor│   │ • White  │
│ • Lago   │   │ • SSO    │   │ • API    │   │ • Multi  │
└──────────┘   └──────────┘   └──────────┘   └──────────┘
```

---

## Comment Contribuer

1. **Voter sur les features** : Utilisez les issues GitHub
2. **Proposer des idées** : Ouvrez une discussion
3. **Contribuer du code** : Fork + PR
4. **Tester les betas** : Rejoignez le programme beta

---

## Changelog

### v0.1.0 (En cours)
- Initial project setup
- Documentation architecture
- Docker Compose base
