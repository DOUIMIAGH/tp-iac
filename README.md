# TP — Infrastructure as Code avec Terraform et Docker

## Installation

Installer Terraform version `1.5.0` ou supérieure, Docker Desktop ou Docker Engine, Git et un éditeur de texte. Démarrer Docker Desktop ou le service Docker avant d'utiliser Terraform.

Vérifier les outils :

```bash
terraform -version
docker --version
docker info
git --version
```

La commande `docker info` doit fonctionner. Récupérer ensuite le projet et l'initialiser :

```bash
git clone https://github.com/DOUIMIAGH/tp-iac.git
cd tp-iac
terraform init
```

## Déploiement et tests

La configuration finale utilise le conteneur `tp-iac-web`, le réseau `tp-iac-web-network` et le port local `8082`.

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

Examiner le plan avant l'application et confirmer avec `yes`. Ouvrir `http://localhost:8082` dans un navigateur ou tester avec :

```bash
curl http://localhost:8082
docker ps
docker network ls
```

La page personnalisée du dossier `html/` doit apparaître.

## Destruction

Examiner le plan de destruction, puis confirmer la destruction avec `yes` :

```bash
terraform plan -destroy
terraform destroy
docker ps -a
docker network ls
terraform state list
```

Le conteneur et le réseau du projet doivent être absents des listes Docker, et l'état ne doit plus contenir de ressources. L'image Nginx reste localement grâce à `keep_locally = true`.

Le nettoyage a été effectué à la fin du TP. Pour consulter de nouveau la page, il faut redéployer le projet avec les commandes ci-dessus.

## 9. Personnaliser la page Web

La page `html/index.html` contient un titre personnalisé, un paragraphe de présentation et la date du TP : le 12 octobre 2026.

Après modification, une requête sur `http://localhost:8080` renvoie le nouveau contenu. Le conteneur conserve le même identifiant et reste en cours d'exécution : la mise à jour ne nécessite pas de reconstruire l'image ni de recréer le conteneur.

**Quelle est la différence entre un montage bind et la copie d'un fichier dans une image Docker ?**

Un montage bind rend un fichier ou un dossier de la machine hôte accessible dans le conteneur pendant son exécution. Une modification du fichier local est directement visible dans le conteneur.

L'instruction `COPY` copie un fichier dans l'image lors de sa construction. Modifier ensuite le fichier local ne modifie pas l'image existante. Pour intégrer la nouvelle version, il faut reconstruire l'image et déployer un conteneur utilisant cette image.

## 10. Créer un réseau Docker dédié

Commande exécutée :

```bash
docker network inspect tp-iac-nginx-network
```

L'inspection confirme que le réseau `tp-iac-nginx-network` utilise le driver `bridge` et que le conteneur `tp-iac-nginx` y est connecté.

**Pourquoi le conteneur est-il connecté à ce réseau ?**

Le bloc `networks_advanced` de `docker_container.web` référence `docker_network.app_network.name`. Cette déclaration rattache le conteneur au réseau dédié du projet, sur lequel les conteneurs connectés peuvent communiquer entre eux.

**Quel est l'intérêt de déclarer le réseau dans Terraform ?**

Sa création est automatisée et reproductible à partir du code. Terraform déduit la dépendance du conteneur envers le réseau et crée le réseau avant le conteneur. Il gère également sa suppression lors de la destruction du projet.

**Vérification de la suppression du réseau :** le réseau initial a été remplacé par `tp-iac-dev-network` à l'étape 12. Après la destruction à l'étape 18, `docker network ls` confirme l'absence du réseau du projet.

## 11. Limiter l'exposition du service

La propriété `ip = "127.0.0.1"` est déjà définie dans le bloc `ports` de `main.tf`.

Commandes exécutées :

```bash
terraform plan
terraform apply
curl http://127.0.0.1:8080
```

Le plan affiche `No changes` et l'application ne modifie aucune ressource. La requête HTTP renvoie la page personnalisée. La commande `docker port tp-iac-nginx 80/tcp` confirme la publication sur `127.0.0.1:8080`.

**Quelle est la différence entre `127.0.0.1` et une écoute sur toutes les interfaces ?**

`127.0.0.1` est l'adresse de boucle locale de la machine. Une écoute sur cette adresse sert à limiter l'accès au service aux connexions locales.

Une écoute sur `0.0.0.0` accepte les connexions sur toutes les interfaces IPv4 de l'hôte, notamment son interface réseau. Le service peut alors être accessible depuis d'autres machines, selon le réseau et les règles du pare-feu.

## 12. Paramétrer les environnements avec des variables

Le fichier local `dev.tfvars` contient :

```hcl
container_name = "tp-iac-dev"
external_port  = 8081
```

Commandes exécutées :

```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
curl http://localhost:8081
```

Le plan prévoit `2 to add, 0 to change, 2 to destroy` : le conteneur et le réseau sont remplacés. L'application crée `tp-iac-dev` et `tp-iac-dev-network`. La page personnalisée est accessible sur `http://localhost:8081`.

Le fichier de variables utilise le même état local que la configuration précédente. Il ne crée pas automatiquement un état indépendant. Le passage aux paramètres de développement remplace donc ici les ressources existantes. Le plan doit être examiné avant chaque application.

`dev.tfvars` est exclu du versionnement par la règle `*.tfvars` du fichier `.gitignore`.

## 13. Inspecter l'état Terraform

Commandes exécutées :

```bash
terraform state list
terraform state show docker_container.web
terraform output
```

Outputs observés :

```text
container_name = "tp-iac-dev"
network_name   = "tp-iac-dev-network"
website_url    = "http://localhost:8081"
```

**1. Quelles ressources apparaissent dans `terraform state list` ?**

```text
docker_container.web
docker_image.nginx
docker_network.app_network
```

**2. Quelles informations affiche `terraform state show` ?**

La commande affiche les attributs enregistrés pour la ressource : identifiant du conteneur, nom, image utilisée, configuration réseau, ports et montages. Pour `docker_container.web`, elle indique notamment le nom `tp-iac-dev`, le réseau `tp-iac-dev-network`, le port interne `80`, le port externe `8081` lié à `127.0.0.1` et le montage bind du dossier `html/` vers `/usr/share/nginx/html`.

**3. Pourquoi l'état Terraform doit-il être protégé ?**

L'état conserve la correspondance entre les ressources déclarées et les objets réellement gérés. Sa perte ou une modification incorrecte peut perturber leur suivi et les opérations suivantes. Il faut donc limiter son accès et protéger ses sauvegardes.

**4. Pourquoi faut-il éviter de publier cet état dans un dépôt public ?**

Un état peut contenir des informations sur l'infrastructure et des valeurs sensibles, notamment des identifiants ou des secrets. Le publier pourrait les exposer. Les règles `*.tfstate` et `*.tfstate.*` du fichier `.gitignore` excluent l'état et ses sauvegardes du versionnement.

## 14. Observer une dérive de configuration

L'expérience utilise la configuration de développement déployée à l'étape 12.

Avant l'arrêt manuel, `terraform plan -var-file="dev.tfvars"` affiche `No changes`. Le conteneur est ensuite arrêté :

```bash
docker stop tp-iac-dev
terraform plan -var-file="dev.tfvars"
```

Le conteneur passe à l'état `exited`. Avec le provider Docker `3.9.0`, le plan propose de créer à nouveau `docker_container.web` :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

L'image et le réseau ne sont pas modifiés. L'arrêt manuel a créé une différence entre l'infrastructure attendue et son état réel.

La restauration et les vérifications sont effectuées avec :

```bash
terraform apply -var-file="dev.tfvars"
curl http://localhost:8081
terraform plan -var-file="dev.tfvars"
```

Le conteneur est recréé avec un nouvel identifiant, puis la page personnalisée répond de nouveau sur le port `8081`. Le dernier plan affiche `No changes. Your infrastructure matches the configuration.` : l'infrastructure est de nouveau conforme.

## 15. Versionner avec Git

**Comment l'historique Git facilite-t-il la revue, la collaboration et le retour sur une modification ?**

- **Revue :** chaque commit regroupe des modifications avec un auteur et un message. `git log` permet de parcourir l'historique et `git show` d'examiner les changements d'un commit.
- **Collaboration :** les commits permettent de partager les évolutions du projet et de retrouver leur origine. Les branches isolent les modifications avant leur intégration.
- **Retour sur une modification :** `git revert <commit>` crée un nouveau commit qui annule les changements du commit concerné, tout en conservant l'historique. Pour répercuter un changement de configuration sur l'infrastructure, il faut ensuite examiner `terraform plan` et exécuter `terraform apply`.

## 16. Automatiser avec un Makefile

Le `Makefile` fournit les cibles `init`, `fmt`, `validate`, `plan`, `apply` et `destroy`. Les commandes commencent par une tabulation.

Commandes exécutées avec succès :

```bash
make init
make fmt
make validate
make plan
```

`make plan` exécute `terraform plan` sans charger `dev.tfvars`. Il utilise donc les valeurs par défaut : `tp-iac-nginx` et le port `8080`. L'environnement déployé utilise encore `tp-iac-dev` et le port `8081` ; le plan propose de remplacer le conteneur et le réseau : `2 to add, 0 to change, 2 to destroy`.

Ce plan n'a pas été appliqué. Le Makefile simplifie les commandes récurrentes ; le plan doit toujours être examiné avant un déploiement.

## 17. Ajouter des contrôles CI avec GitHub Actions

Le workflow `.github/workflows/terraform.yml` est configuré pour les événements `push` et `pull_request`. Il récupère le dépôt, installe Terraform, puis exécute les contrôles suivants :

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Lors de l'étape 17, ces trois commandes ont été exécutées avec succès localement. L'exécution sur GitHub Actions a ensuite été vérifiée à l'exercice 6 de la section 19, après publication des commits.

Le workflow contrôle le formatage et la validité de la configuration. Il n'effectue pas le déploiement Docker : le runner n'est pas configuré pour piloter le moteur Docker de la machine locale.

## 18. Détruire l'infrastructure

Le nettoyage utilise les variables de l'environnement de développement déployé à l'étape 12.

Commandes exécutées :

```bash
terraform plan -destroy -var-file="dev.tfvars"
terraform destroy -var-file="dev.tfvars"
```

Le plan affiche `0 to add, 0 to change, 3 to destroy` et concerne uniquement les trois ressources du projet : `docker_container.web`, `docker_network.app_network` et `docker_image.nginx`. Après confirmation avec `yes`, Terraform affiche `Destroy complete! Resources: 3 destroyed.`

Vérifications effectuées :

```bash
docker ps -a
docker network ls
terraform state list
docker image inspect nginx:alpine --format '{{.Id}}'
```

Le conteneur `tp-iac-dev` et le réseau `tp-iac-dev-network` ne figurent plus dans les listes Docker. `terraform state list` ne retourne aucune ressource.

L'image `nginx:alpine` reste présente localement, conformément à `keep_locally = true`, même si Terraform ne la suit plus dans l'état.

## 19. Exercices complémentaires

### Exercice 1 — Modifier le nom

La valeur par défaut de `container_name` dans `variables.tf` passe de `tp-iac-nginx` à `tp-iac-web`.

Commandes exécutées avec succès :

```bash
terraform fmt
terraform validate
terraform plan
```

Le plan affiche `3 to add, 0 to change, 0 to destroy`. L'état est vide après la destruction de l'étape 18 : Terraform prévoit donc la création des trois ressources du projet.

- `docker_container.web` utilisera le nom `tp-iac-web`.
- `docker_network.app_network` utilisera le nom `tp-iac-web-network`, dérivé de `container_name` dans `main.tf`.
- `docker_image.nginx` sera de nouveau gérée par Terraform ; l'image `nginx:alpine` est déjà présente localement.

L'output `website_url` prévu reste `http://localhost:8080`, le port n'ayant pas été modifié. Le plan n'a pas été appliqué.

### Exercice 2 — Modifier le port

La valeur par défaut de `external_port` dans `variables.tf` passe de `8080` à `8082`.

Commandes exécutées :

```bash
terraform plan
terraform apply
curl --fail --silent --show-error --include --max-time 15 http://localhost:8082
docker port tp-iac-web 80/tcp
```

Le plan prévoit `3 to add, 0 to change, 0 to destroy`, l'état étant vide et le plan de l'exercice 1 n'ayant pas été appliqué. Le conteneur prévu est `tp-iac-web`, connecté au réseau `tp-iac-web-network`, avec son port interne `80` publié sur `127.0.0.1:8082`.

Après confirmation avec `yes`, Terraform affiche `Apply complete! Resources: 3 added, 0 changed, 0 destroyed.` L'output `website_url` vaut `http://localhost:8082`.

La requête HTTP renvoie `200 OK` et la page personnalisée du TP. `docker port` confirme la publication sur `127.0.0.1:8082`.

### Exercice 3 — Ajouter une variable

La variable `network_name`, de type `string`, est ajoutée dans `variables.tf` avec la valeur par défaut `tp-iac-web-network`. La ressource `docker_network.app_network` utilise désormais `name = var.network_name` : le nom du réseau peut être choisi indépendamment du nom du conteneur.

L'output `network_name` référence `docker_network.app_network.name` pour afficher le nom du réseau choisi.

Vérifications exécutées :

```bash
terraform fmt
terraform validate
terraform plan
terraform output -raw network_name
```

La configuration est valide. Le plan affiche `No changes`, car la valeur par défaut correspond au nom du réseau déjà déployé. L'output renvoie `tp-iac-web-network`.

### Exercice 4 — Comprendre l'état

La commande `terraform state list` retourne les trois ressources gérées :

```text
docker_container.web
docker_image.nginx
docker_network.app_network
```

Les dépendances sont définies par les références dans `main.tf` :

- `docker_container.web` dépend de `docker_image.nginx` grâce à `image = docker_image.nginx.image_id`. L'image fournit les fichiers et le programme Nginx nécessaires au conteneur ; elle doit être disponible avant sa création.
- `docker_container.web` dépend de `docker_network.app_network` grâce à `networks_advanced.name = docker_network.app_network.name`. Le réseau doit exister pour que Docker puisse y connecter le conteneur.

Terraform déduit automatiquement ces dépendances. Il prépare l'image et crée le réseau avant de créer le conteneur. Aucune dépendance directe n'est déclarée entre l'image et le réseau : leur préparation peut se faire en parallèle.

### Exercice 5 — Détecter une dérive

Le conteneur `tp-iac-web` est initialement en cours d'exécution. Il est arrêté manuellement depuis Docker :

```bash
docker stop tp-iac-web
docker inspect --format '{{.State.Status}}' tp-iac-web
terraform plan
```

Docker confirme l'état `exited`. Avec le provider Docker `3.9.0`, Terraform propose de recréer `docker_container.web` et affiche `1 to add, 0 to change, 0 to destroy`. L'image et le réseau ne sont pas modifiés. L'arrêt manuel a créé une dérive par rapport à l'état attendu du conteneur.

La restauration et les vérifications sont effectuées avec :

```bash
terraform apply
docker inspect --format '{{.Id}} {{.State.Status}}' tp-iac-web
curl --fail --silent --show-error --include --max-time 15 http://localhost:8082
terraform plan
```

Après confirmation avec `yes`, Terraform affiche `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.` Le conteneur est recréé avec un nouvel identifiant et son état est `running`.

La page personnalisée répond de nouveau avec `200 OK` sur `http://localhost:8082`. Le dernier plan affiche `No changes. Your infrastructure matches the configuration.` : la dérive est corrigée.

### Exercice 6 — CI/CD

Le projet est publié dans le dépôt [DOUIMIAGH/tp-iac](https://github.com/DOUIMIAGH/tp-iac).

Commandes utilisées pour relier le dépôt local et publier les commits :

```bash
git remote add origin git@github.com:DOUIMIAGH/tp-iac.git
git push -u origin main
```

Le premier push déclenche le workflow `Terraform Checks`, qui réussit.

Pour tester le contrôle, l'alignement de la ligne `default = 8082` dans `variables.tf` est volontairement modifié. Ce changement est commité puis poussé. Sur GitHub Actions, l'étape `Format Check` échoue et l'étape suivante, `Validate`, est ignorée.

Le fichier est ensuite corrigé avec `terraform fmt -recursive`. Le contrôle local `terraform fmt -check -recursive` réussit. La correction est commitée et poussée ; le workflow réussit de nouveau.

| Vérification | Commit | Résultat GitHub Actions |
| --- | --- | --- |
| Premier push | `d6d58f2` | [Réussite](https://github.com/DOUIMIAGH/tp-iac/actions/runs/38248149242) |
| Défaut de formatage volontaire | `c42d3c3` | [Échec de Format Check](https://github.com/DOUIMIAGH/tp-iac/actions/runs/38248326444) |
| Correction du formatage | `1a03600` | [Réussite](https://github.com/DOUIMIAGH/tp-iac/actions/runs/38248491161) |

### Exercice 7 — Nettoyage

Le plan de destruction est examiné avant de supprimer les ressources :

```bash
terraform plan -destroy
terraform destroy
```

Le plan affiche `0 to add, 0 to change, 3 to destroy` et concerne les trois ressources du projet. Après confirmation avec `yes`, Terraform affiche `Destroy complete! Resources: 3 destroyed.`

Vérifications exécutées :

```bash
docker ps -a
docker network ls
terraform state list
docker image inspect nginx:alpine --format '{{.Id}}'
```

Le conteneur `tp-iac-web` et le réseau `tp-iac-web-network` sont absents des listes Docker. `terraform state list` ne retourne aucune ressource. L'image `nginx:alpine` reste présente localement, conformément à `keep_locally = true`.

**Pourquoi ne faut-il pas supprimer manuellement l'état Terraform pour nettoyer une infrastructure active ?**

Supprimer le fichier d'état ne supprime pas les ressources réelles. Terraform perd la correspondance entre les ressources déclarées et leurs identifiants dans Docker ; il ne peut plus les gérer à partir de cet état. Une application ultérieure peut alors provoquer des conflits de noms ou des créations en double. Il faut examiner `terraform plan -destroy`, puis utiliser `terraform destroy` pour supprimer les ressources et mettre à jour l'état.

## 20. Questions de compréhension

### 1. Quelle est la différence entre `terraform init`, `terraform plan` et `terraform apply` ?

- `terraform init` prépare le répertoire de travail : il installe les providers nécessaires et initialise le stockage de l'état.
- `terraform plan` compare la configuration à l'état connu et aux ressources réelles, puis présente les créations, modifications et suppressions prévues, sans déployer l'infrastructure.
- `terraform apply` exécute les actions du plan pour créer, modifier ou supprimer les ressources et mettre à jour l'état.

### 2. Quel est le rôle d'un provider Terraform ?

Un provider permet à Terraform de communiquer avec le système qui gère les ressources. Il traduit les déclarations Terraform en opérations de création, de lecture, de modification et de suppression. Dans ce TP, le provider Docker communique avec le moteur Docker pour gérer l'image Nginx, le réseau et le conteneur.

### 3. À quoi sert le fichier `terraform.tfstate` ?

Le fichier d'état conserve la correspondance entre les ressources déclarées dans le code et les objets réellement gérés, notamment leurs identifiants et leurs attributs connus. Terraform l'utilise pour suivre les ressources existantes et déterminer les opérations nécessaires avec la configuration et les informations récupérées auprès du provider. Supprimer ce fichier ne supprime pas les ressources réelles.

### 4. Pourquoi utilise-t-on des variables et des outputs ?

Les variables permettent de choisir des paramètres sans réécrire les ressources, comme le nom du conteneur, le port HTTP ou le nom du réseau. Les outputs exposent des informations utiles après l'application, comme le nom du conteneur déployé et l'URL du serveur. Ils facilitent la réutilisation de la configuration et la consultation des résultats du déploiement.

### 5. Qu'est-ce qu'une dérive de configuration ?

Une dérive est une différence entre la configuration attendue et l'infrastructure réelle, par exemple après une intervention manuelle. Dans ce TP, arrêter le conteneur avec Docker crée une dérive : le conteneur devrait être en cours d'exécution. `terraform plan` permet d'observer les changements proposés pour retrouver la configuration attendue ; l'application de ce plan rétablit le service.

### 6. Quelle différence existe-t-il entre Infrastructure as Code et configuration manuelle ?

L'Infrastructure as Code décrit l'infrastructure dans des fichiers que l'on peut versionner, examiner et utiliser pour automatiser les opérations. Dans ce TP, les ressources Docker sont déclarées dans les fichiers Terraform. Une configuration manuelle consiste à effectuer les opérations directement, par des commandes ou une interface ; il faut alors conserver la trace des actions et les reproduire pour obtenir le même environnement.

### 7. Quel est l'intérêt de Git dans un projet IaC ?

Git conserve les versions du code et l'historique des modifications avec leur auteur et leur message. Il permet de comparer les changements, de les examiner avant intégration, de travailler à plusieurs avec des branches et de revenir sur une modification. Un retour dans le code doit ensuite être examiné avec `terraform plan` et appliqué pour être répercuté sur l'infrastructure.

### 8. Quelle est la différence entre un contrôle CI et un déploiement CD ?

Un contrôle CI vérifie automatiquement les modifications du code, par exemple son formatage et la validité de la configuration. Un déploiement CD applique une version à un environnement pour mettre en service les changements. Dans ce TP, GitHub Actions effectue l'initialisation, le contrôle du formatage et la validation Terraform. Le déploiement Docker est réalisé localement avec `terraform apply`.

### 9. Pourquoi faut-il examiner le plan avant d'appliquer une modification ?

Le plan indique les ressources que Terraform prévoit de créer, de modifier ou de supprimer. Son examen permet de vérifier que les actions correspondent à la modification souhaitée, notamment les noms, les ports et les éventuels remplacements de ressources. Il aide à repérer une suppression ou un changement involontaire avant son application. Dans ce TP, changer de fichier de variables avec le même état peut provoquer le remplacement du conteneur et du réseau.

### 10. Quelles précautions faut-il prendre avec les fichiers d'état et les secrets ?

L'état peut contenir des informations sensibles : il faut restreindre son accès et protéger ses sauvegardes. Les fichiers d'état et les fichiers de variables contenant des secrets doivent être exclus de Git avec `.gitignore`. Les secrets ne doivent pas être inscrits dans le code ni publiés dans les logs ; ils doivent être conservés dans un stockage adapté avec des accès limités. En équipe, un stockage partagé et protégé de l'état, avec un verrouillage adapté, évite les modifications concurrentes. Il ne faut pas supprimer ou modifier manuellement l'état pour nettoyer une infrastructure active.
