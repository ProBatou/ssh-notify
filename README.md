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

4. Enregistrez les modifications et enregistrer le fichier dans etc.
   
   ```shell
   cp ssh-notify.conf.template /etc/ssh-notify.conf
   ```

## Utilisation

Le script sera automatiquement exécuté chaque fois qu'un utilisateur établira une connexion SSH sur la machine. Les notifications seront envoyées en fonction de la configuration définie dans le fichier `ssh-notify.conf`.

## Remarques

- Assurez-vous que votre machine a accès à Internet pour pouvoir envoyer les notifications.
- Veillez à garder votre fichier de configuration sécurisé, car il contient des informations d'identification sensibles.

N'hésitez pas à personnaliser le fichier README en ajoutant plus de détails sur le fonctionnement de votre script ou en fournissant des instructions supplémentaires pour les utilisateurs.
