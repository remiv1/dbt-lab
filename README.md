# dbt-lab

Ce dépôt est un **projet d’apprentissage** destiné à expérimenter dbt sur un petit domaine e-commerce. Il ne représente pas un système réel, un jeu de données de production ni une architecture prête à être déployée telle quelle.

## Évolution de dbt et des moteurs

Le parcours d'apprentissage comprend plusieurs étapes :

- **V1 : dbt Core 1.x avec PostgreSQL.** Les scripts `init-db.sql` et `launch-postgres.sh` conservent cet ancien parcours local.
- **V2 : dbt 2.x avec DuckDB.** dbt V2 fournit un driver DuckDB natif ; aucun adaptateur Python séparé n'est requis.
- **Configuration actuelle :** la CI utilise `dbt==2.0.13` et DuckDB. Le projet local peut utiliser le fichier `ecommerce/dev.duckdb`.

Le retour à DuckDB a aussi modifié la CI et le test d'intégration : ils n'utilisent plus de service PostgreSQL ni `psql`.

## Objectifs pédagogiques

Le projet permet de pratiquer les bases d’un projet dbt :

- déclarer des sources et construire des modèles avec `source()` et `ref()` ;
- séparer les transformations de préparation (_staging_) des modèles analytiques (_marts_) ;
- utiliser des vues, des tables et un modèle incrémental ;
- ajouter des tests de données, un test SQL personnalisé et un snapshot ;
- écrire et appeler des macros Jinja ;
- vérifier un chargement incrémental sur DuckDB avec des états successifs des données.

## Organisation

```text
.
├── init-db.sql                    # Initialisation PostgreSQL de l'exercice V1
├── launch-postgres.sh             # PostgreSQL local pour l'exercice V1
├── .github/workflows/ci.yml       # CI dbt V2 avec DuckDB
└── ecommerce/                     # Projet dbt
    ├── models/
    │   ├── staging/               # Nettoyage et typage des sources raw
    │   └── marts/                 # Modèles analytiques et incrémentaux
    ├── macros/                    # Macros Jinja réutilisables
    ├── tests/                     # Tests SQL personnalisés
    ├── snapshots/                 # Exemple de snapshot dbt
    ├── seeds/                     # Fichiers CSV d'exemple
    └── integration_tests/         # Fixtures et test incrémental DuckDB
```

Le flux principal est :

```text
DuckDB raw → modèles staging (vues) → modèles marts (tables)
```

Les modèles `stg_customers` et `stg_orders` normalisent les champs issus des sources. Les marts comprennent notamment `customer_orders` (indicateurs par client), `prospects` (clients sans commande) et `orders_incremental` (suivi incrémental des commandes à partir de leur `row_hash`). Les dossiers `analyses/`, `seeds/`, `snapshots/` et `macros/` servent à explorer d'autres fonctionnalités de dbt.

## Prérequis

- Python 3.12 (dbt V2 nécessite Python 3.10 ou plus) ;
- dbt V2 `2.0.13`, installé dans le virtualenv du dépôt ;
- `jq` pour le test d'intégration local. Il est disponible sur les runners GitHub Actions de la CI.

DuckDB est intégré à dbt V2. La CI utilise un fichier DuckDB temporaire et n'a besoin ni de Podman ni d'un serveur de base de données.

## Démarrage local

Depuis la racine du dépôt, créer un virtualenv et y installer dbt :

```bash
python3 -m venv .venv
.venv/bin/python -m pip install dbt==2.0.13
source .venv/bin/activate
```

Configurer le profil `ecommerce` dans `~/.dbt/profiles.yml` (ou le répertoire défini par `DBT_PROFILES_DIR`). Remplacer le chemin par un chemin absolu vers `ecommerce/dev.duckdb` :

```yaml
ecommerce:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: /chemin/absolu/vers/dbt-lab/ecommerce/dev.duckdb
      schema: main
    integration:
      type: duckdb
      path: /chemin/absolu/vers/dbt-lab/ecommerce/dev.duckdb
      schema: dbt_integration
```

Depuis `ecommerce/`, construire les modèles et charger les seeds dans le schéma brut configuré :

```bash
dbt debug
dbt build --vars '{raw_schema: main_raw}'
```

`dbt build` construit les seeds, modèles et tests sélectionnés. Pour travailler séparément : `dbt seed`, `dbt run`, `dbt test` et `dbt snapshot`.

## Test d'intégration incrémental

Depuis `ecommerce/`, lancer le script avec un profil `integration` qui pointe vers le même fichier DuckDB :

```bash
bash integration_tests/test_orders_incremental.sh
```

Le script charge successivement les deux fixtures via `dbt run-operation --sql`, puis interroge le résultat avec `dbt show --inline --output json`. Il vérifie l'état initial, l'UPDATE de la commande `9902`, l'INSERT de `9903`, l'absence de doublons et l'idempotence d'une nouvelle exécution.

**Attention :** le test supprime les schémas `integration_raw`, `dbt_integration_staging` et `dbt_integration_marts` dans le fichier DuckDB ciblé. Utiliser une base dédiée à l'intégration, jamais une base contenant des données à conserver.

## Ancien exercice PostgreSQL

`launch-postgres.sh` et `init-db.sql` sont conservés pour rejouer l'exercice V1 avec PostgreSQL. Ils ne sont utilisés ni par le test d'intégration actuel ni par la CI dbt V2.

## Parcours suggéré

1. Examiner les sources dans `models/staging/_sources.yml` et les transformations de staging.
2. Suivre les dépendances entre modèles avec `ref()` et comparer staging et marts.
3. Lire les tests déclarés dans les fichiers `schema.yml` et le test SQL personnalisé.
4. Étudier `orders_incremental.sql`, puis les fixtures `orders_n.sql` et `orders_n_plus_1.sql`.
5. Modifier une transformation ou une donnée d'exemple et observer l'effet avec `dbt build` et le test d'intégration.

La CI GitHub Actions installe `dbt==2.0.13`, configure les cibles `ci` et `integration` sur le même fichier DuckDB temporaire, exécute `dbt build`, puis lance le test d'intégration incrémental.
