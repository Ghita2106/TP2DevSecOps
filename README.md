LETTERBOX / TP2 DEVSECOPS – RUNTIME GATE (STAGING)

============================================================
CONTEXTE
============================================================
Ce projet est une base minimale réalisée dans le cadre du TP2 DevSecOps.
L’objectif est de compléter un pipeline DevSecOps existant par un contrôle
post-déploiement (staging) basé sur l’analyse de logs applicatifs structurés.

Le pipeline ne se contente plus de builder et déployer : il observe le
comportement réel de l’application après déploiement et bloque si des
seuils sont dépassés.

============================================================
OBJECTIFS DU TP
============================================================
- Déployer une application web simple en environnement staging
- Générer des logs applicatifs structurés (JSON)
- Générer du trafic applicatif reproductible
- Extraire des métriques runtime à partir des logs
- Mettre en place une runtime gate automatique :
  - trop d’erreurs HTTP 5xx
  - latence p95 trop élevée
  - patterns suspects dans les requêtes

============================================================
ARCHITECTURE TECHNIQUE
============================================================
- Application : Flask (microservice "catalog")
- Conteneurisation : Docker
- Orchestration locale : Docker Compose
- Langages :
  - Python (application + calcul métriques)
  - Bash (scripts de supervision)

============================================================
STRUCTURE DU PROJET
============================================================
.
├── compose.staging.yml
├── services/
│   └── catalog/
│       ├── app.py
│       ├── requirements.txt
│       └── Dockerfile
├── monitoring/
│   ├── smoke.sh
│   ├── supervision.sh
│   ├── traffic.sh
│   ├── log_metrics.py
│   └── log_gate.sh
└── reports/

============================================================
DESCRIPTION DU SERVICE CATALOG
============================================================
Endpoints exposés :
- GET /health
  - Vérifie que le service est opérationnel
  - Retourne HTTP 200

- GET /search?q=xxx
  - Endpoint applicatif simple pour générer du trafic
  - Retourne un JSON fictif

Chaque requête génère :
- un Request-Id (fourni ou généré)
- une ligne de log JSON (1 requête = 1 ligne)

============================================================
FORMAT DES LOGS JSON
============================================================
Chaque requête produit une ligne JSON avec au minimum :
- ts              : timestamp UTC
- level           : niveau de log
- service         : nom du service
- request_id      : identifiant de requête
- method          : méthode HTTP
- path            : chemin appelé
- status          : code HTTP
- latency_ms      : latence en millisecondes
- query           : query string (tronquée)

============================================================
SCRIPTS DE MONITORING
============================================================

smoke.sh
- Vérifie que /health est accessible
- Échoue si le service ne répond pas

supervision.sh
- Vérifie la propagation du header X-Request-Id
- Assure la traçabilité des requêtes

traffic.sh
- Génère du trafic normal sur /health et /search
- Mode suspect optionnel (SUSPECT_MODE=1) :
  - génère des patterns ../ et cmd=

log_metrics.py
- Analyse un fichier de logs JSONL
- Calcule :
  - nombre de logs
  - nombre de réponses HTTP 5xx
  - latence p95
  - détection de patterns simples

log_gate.sh
- Orchestration complète de la runtime gate :
  1. smoke tests
  2. supervision
  3. génération de trafic
  4. extraction des logs Docker
  5. calcul des métriques
  6. comparaison aux seuils
  7. succès ou échec du pipeline

============================================================
SEUILS DE SÉCURITÉ (PAR DÉFAUT)
============================================================
- MAX_5XX       = 0
- MAX_P95_MS    = 400 ms
- MAX_TRAV      = 0 (path traversal)

Si un seuil est dépassé, la gate retourne un code d’erreur.

============================================================
LANCEMENT DU PROJET
============================================================

1. Build et déploiement du staging
--------------------------------
docker compose -f compose.staging.yml down -v
docker compose -f compose.staging.yml up -d --build

2. Vérification du service
--------------------------
curl http://localhost:5001/health

3. Lancer la runtime gate
-------------------------
BASE_URL=http://localhost:5001 SERVICE=catalog bash monitoring/log_gate.sh

Résultat attendu :
[gate] OK

============================================================
TEST D’ÉCHEC VOLONTAIRE
============================================================
Pour vérifier que la gate fonctionne réellement :

BASE_URL=http://localhost:5001 SUSPECT_MODE=1 bash monitoring/traffic.sh
BASE_URL=http://localhost:5001 SERVICE=catalog bash monitoring/log_gate.sh

Résultat attendu :
[gate] FAIL

============================================================
INTÉRÊT DEVSECOPS
============================================================
Ce TP illustre :
- le principe de sécurité runtime
- la complémentarité avec les scans statiques (SAST/SCA)
- l’automatisation de décisions de sécurité dans un pipeline CI/CD
- l’approche "security as code"

============================================================
FIN
============================================================
