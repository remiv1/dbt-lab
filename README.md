# dbt-lab

Ce dépôt est un **projet d’apprentissage** destiné à expérimenter _**dbt v1**_ sur un petit domaine e-commerce. Il ne représente pas un système réel, un jeu de données de production ni une architecture prête à être déployée telle quelle.

## Objectifs pédagogiques

Le projet permet de pratiquer les bases d’un projet dbt :

- déclarer des sources et construire des modèles avec `source()` et `ref()` ;
- séparer les transformations de préparation (_staging_) des modèles analytiques (_marts_) ;
- utiliser des vues, des tables et un modèle incrémental ;
- ajouter des tests de données, un test SQL personnalisé et un snapshot ;
- écrire et appeler des macros Jinja ;
- vérifier un chargement incrémental sur PostgreSQL avec des états successifs des données.

## Organisation

```text
.
├── init-db.sql                    # Schéma raw et données d'exemple PostgreSQL
├── launch-postgres.sh             # Démarrage local de PostgreSQL avec Podman
├── .github/workflows/ci.yml       # Construction dbt et tests dans GitHub Actions
└── ecommerce/                     # Projet dbt
    ├── models/
    │   ├── staging/               # Nettoyage et typage des sources raw
    │   └── marts/                 # Modèles analytiques et incrémentaux
    ├── macros/                    # Macros Jinja réutilisables
    ├── tests/                     # Tests SQL personnalisés
    ├── snapshots/                 # Exemple de snapshot dbt
    ├── seeds/                     # Fichiers CSV d'exemple
    └── integration_tests/         # Fixtures et test incrémental PostgreSQL
```

Le flux principal est :

```text
PostgreSQL raw → modèles staging (vues) → modèles marts (tables)
```

Les modèles `stg_customers` et `stg_orders` normalisent les champs issus des sources. Les marts comprennent notamment `customer_orders` (indicateurs par client), `prospects` (clients sans commande) et `orders_incremental` (suivi incrémental des commandes à partir de leur `row_hash`). Les dossiers `analyses/`, `seeds/`, `snapshots/` et `macros/` servent à explorer d'autres fonctionnalités de dbt.

## Prérequis

- Podman pour lancer PostgreSQL localement ;
- Python et dbt Core avec l'adaptateur PostgreSQL. La CI utilise `dbt-core==1.12.3` et `dbt-postgres==1.11.0` ;
- `psql` pour initialiser et inspecter la base.

Les identifiants définis par le conteneur local sont réservés à cet exercice : utilisateur `dbt`, mot de passe `dbt`, base `ecommerce`. Ne pas les réutiliser dans un environnement partagé ou réel.

## Démarrage local

Depuis la racine du dépôt, démarrer PostgreSQL :

```bash
./launch-postgres.sh
```

Initialiser le schéma `raw` et ses données d'exemple :

```bash
PGPASSWORD=dbt psql \
  -h localhost -p 5432 -U dbt -d ecommerce \
  -v ON_ERROR_STOP=1 -f init-db.sql
```

Configurer ensuite le profil dbt `ecommerce` dans `~/.dbt/profiles.yml` (ou dans le répertoire indiqué par `DBT_PROFILES_DIR`). Il doit fournir une sortie PostgreSQL, par exemple une cible `ci` avec `host: localhost`, `port: 5432`, `user: dbt`, `password: dbt`, `dbname: ecommerce` et `schema: dbt`. Le test d'intégration utilise en plus une cible nommée `integration`.

Puis lancer les commandes depuis le projet dbt :

```bash
cd ecommerce
dbt debug
dbt build
```

`dbt build` exécute les modèles et les tests associés. Pour travailler séparément : `dbt run` construit les modèles, `dbt test` exécute les tests et `dbt snapshot` met à jour les snapshots configurés.

## Test d'intégration incrémental

Depuis `ecommerce/`, avec PostgreSQL disponible et la variable `PGPASSWORD` définie :

```bash
bash integration_tests/test_orders_incremental.sh
```

Le script charge un premier état des commandes, vérifie le résultat après une première construction, charge un état suivant puis contrôle les insertions, les mises à jour et l'idempotence d'une nouvelle exécution.

**Attention :** ce test supprime les schémas `integration_raw`, `dbt_integration_staging` et `dbt_integration_marts` au début et à la fin de son exécution. Il est conçu pour une base dédiée à l'intégration, jamais pour une base contenant des données à conserver.

## Parcours suggéré

1. Examiner les sources dans `models/staging/_sources.yml` et les transformations de staging.
2. Suivre les dépendances entre modèles avec `ref()` et comparer staging et marts.
3. Lire les tests déclarés dans les fichiers `schema.yml` et le test SQL personnalisé.
4. Étudier `orders_incremental.sql`, puis les fixtures `orders_n.sql` et `orders_n_plus_1.sql`.
5. Modifier une transformation ou une donnée d'exemple et observer l'effet avec `dbt build` et le test d'intégration.

La CI GitHub Actions initialise PostgreSQL, exécute `dbt build`, puis lance le test d'intégration incrémental.
