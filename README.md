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

**Vérification de la suppression du réseau :** elle sera effectuée lors du nettoyage prévu à l'étape 18.

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
