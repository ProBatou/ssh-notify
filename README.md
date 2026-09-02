# SSH Connection Notifier

Ce script Bash vous permet de recevoir une notification à chaque fois qu'une connexion SSH est établie sur votre machine. La notification est envoyée à un service en ligne pour une gestion facile.

## Prérequis

Avant d'utiliser ce script, assurez-vous d'avoir installé les dépendances suivantes :

- `curl`: Utilisé pour envoyer les notifications HTTP.

## Configuration

1. Copiez le fichier `ssh-notify.sh` dans le répertoire `/etc/profile.d/` :

   ```shell
   cp ssh-notify.sh /etc/profile.d/
   ```

2. Ouvrez le fichier de configuration `ssh-notify.conf.template` :

   ```shell
   nano /etc/ssh-notify.conf.template
   ```

3. Modifiez les valeurs des variables suivantes selon vos besoins :

   - `NTFY`: L'URL du service de notification en ligne.
   - `USERNAME`: Votre nom d'utilisateur pour le service de notification.
   - `PASSWORD`: Votre mot de passe pour le service de notification.

4. Enregistrez les modifications et enregistrez le fichier dans `/etc` :

   ```shell
   cp ssh-notify.conf.template /etc/ssh-notify.conf
   ```

## Utilisation

Le script sera automatiquement exécuté chaque fois qu'un utilisateur établira une connexion SSH sur la machine. Les notifications seront envoyées en fonction de la configuration définie dans le fichier `ssh-notify.conf`.

## Releases automatiques

Une GitHub Release est automatiquement créée lorsqu'une modification fonctionnelle est poussée sur `main`, c'est-à-dire lorsqu'un des fichiers suivants change :

- `ssh-notify.sh`
- `ssh-notify.conf.template`

Le workflow utilise un versioning sémantique :

- première release : `v1.0.0` ;
- modification fonctionnelle normale : incrément de la version mineure (`v1.1.0`, `v1.2.0`, etc.) ;
- commit contenant `fix:` ou `[patch]` : incrément de patch ;
- commit indiquant un breaking change (`BREAKING CHANGE:`, `type!:`, ou `[major]`) : incrément de version majeure.

Les notes de version sont générées automatiquement par GitHub et les fichiers `ssh-notify.sh` et `ssh-notify.conf.template` sont joints à la release.

Le workflow peut également être lancé manuellement depuis l'onglet **Actions** de GitHub.

## Remarques

- Assurez-vous que votre machine a accès à Internet pour pouvoir envoyer les notifications.
- Veillez à garder votre fichier de configuration sécurisé, car il contient des informations d'identification sensibles.
