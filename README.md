# TP — Infrastructure as Code avec Terraform et Docker

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
