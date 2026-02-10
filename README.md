TP2 DEVSECOPS
RUNTIME SUPERVISION & SECURITY GATE


1. PRÉSENTATION GÉNÉRALE

Ce projet a été réalisé dans le cadre du TP2 DevSecOps.
Il met en œuvre une approche de sécurité post-déploiement
basée sur l’observation du comportement réel de l’application
en environnement de staging.

L’objectif n’est pas la complexité fonctionnelle, mais la
mise en place d’une chaîne DevSecOps cohérente et automatisée.


2. OBJECTIFS DU TRAVAIL

- Déployer une application web en environnement de staging
- Produire des logs applicatifs structurés (JSON)
- Générer du trafic reproductible
- Extraire des métriques runtime
- Mettre en place une gate de sécurité automatisée
- Bloquer le pipeline en cas de dérive détectée


3. ARCHITECTURE TECHNIQUE

- Microservice Flask : catalog
- Conteneurisation : Docker
- Orchestration locale : Docker Compose
- Supervision et automatisation : scripts Bash
- Analyse des logs : Python


4. ORGANISATION DU PROJET
```
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
```

5. VALIDATION DES EXIGENCES DU TP

5.1 Mise en service du staging

Objectif :
Vérifier que l’environnement de staging est opérationnel et
que le service web est accessible.

Localisation :
- compose.staging.yml
- services/catalog/app.py (endpoint /health)

Commandes de validation :
```
docker compose -f compose.staging.yml down -v
docker compose -f compose.staging.yml up -d --build
curl.exe -i http://localhost:5001/health
```

Résultat attendu :
- HTTP 200
- réponse simple « OK »


5.2 Production de logs structurés et Request-Id

Objectif :
Garantir la traçabilité et l’analyse automatique des requêtes.

Localisation :
- services/catalog/app.py
  - middleware before_request
  - middleware after_request

Commandes de validation :
```
curl.exe -i http://localhost:5001/health
docker compose -f compose.staging.yml logs --no-log-prefix catalog | Select-Object -Last 10
```

Test de propagation du Request-Id :
```
curl.exe -i -H "X-Request-Id: test-123" http://localhost:5001/health
```

5.3 Génération de trafic applicatif

Objectif :
Créer un trafic reproductible afin d’alimenter les logs.

Localisation :
- monitoring/traffic.sh

Commande de validation :
```
BASE_URL=http://localhost:5001 bash monitoring/traffic.sh
```

Mode trafic suspect :
```
BASE_URL=http://localhost:5001 SUSPECT_MODE=1 bash monitoring/traffic.sh
```

5.4 Extraction et calcul des métriques runtime

Objectif :
Analyser les logs afin de calculer des indicateurs de santé
et de sécurité de l’application.

Métriques calculées :
- nombre de requêtes
- erreurs HTTP 5xx
- latence p95
- détection de patterns suspects

Localisation :
- monitoring/log_metrics.py

Commandes de validation :
```
mkdir -p reports
docker compose -f compose.staging.yml logs --no-log-prefix --since 2m catalog > reports/catalog_logs.raw
Select-String "^\{" reports/catalog_logs.raw | ForEach-Object { $_.Line } > reports/catalog_logs.jsonl
python3 monitoring/log_metrics.py reports/catalog_logs.jsonl reports/log_report.json
Get-Content reports/log_report.json
```


5.5 Runtime security gate

Objectif :
Automatiser une décision de sécurité post-déploiement.

Fonctionnement :
- exécution des tests
- génération de trafic
- collecte et analyse des logs
- comparaison aux seuils définis
- validation ou échec du pipeline

Localisation :
- monitoring/log_gate.sh

Commande de validation (cas nominal) :
```
BASE_URL=http://localhost:5001 SERVICE=catalog bash monitoring/log_gate.sh
```

Résultat attendu :
[gate] OK


5.6 Démonstration d’un échec contrôlé

Objectif :
Montrer que la gate bloque effectivement en cas de
comportement suspect détecté.

Commande :
```
BASE_URL=http://localhost:5001 SUSPECT_MODE=1 SERVICE=catalog bash monitoring/log_gate.sh
```

Résultat attendu :
[gate] FAIL


6. APPORT DEVSECOPS

Ce travail illustre :
- l’intégration de la sécurité après le déploiement
- l’analyse comportementale en environnement de staging
- l’automatisation de contrôles de sécurité
- le principe de « security as code »


FIN DU DOCUMENT
