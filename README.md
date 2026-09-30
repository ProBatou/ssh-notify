# SSH Connection Notifier

Ce script Bash permet de recevoir une notification lorsqu'une session SSH est ouverte sur votre machine. Il est chargé par le shell depuis `/etc/profile.d/` et envoie la notification au service ntfy configuré.

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

Le script est chargé par `/etc/profile.d/` lors de l'ouverture d'un shell de profil. Une notification est envoyée uniquement si `sshd` a fourni `SSH_CONNECTION` ou `SSH_CLIENT`. Les shells locaux, y compris les terminaux code-server/Codex, sont donc ignorés.

Une variable d'environnement exportée marque la session après la première tentative. Les sous-shells de cette session SSH l'héritent et ne génèrent pas de notifications en double. Les sessions SSH sans TTY sont prises en charge.

L'envoi est informatif et fonctionne en mode *best effort*. Les délais de connexion et d'exécution de `curl` sont limités ; une configuration absente, un service ntfy indisponible ou un échec HTTP ne bloque pas et ne fait pas échouer l'ouverture du shell SSH. La configuration et les identifiants restent exclusivement dans `/etc/ssh-notify.conf`.

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

- Une notification ne pourra être envoyée que si la machine peut joindre le service ntfy, sans que cela conditionne l'accès SSH.
- Veillez à garder votre fichier de configuration sécurisé, car il contient des informations d'identification sensibles.
