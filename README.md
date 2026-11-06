# 📒 Carnet de Dettes

Application Android (Flutter) pour les boutiques d'alimentation : noter facilement les **achats à crédit** et les **paiements** de chaque client, avec une interface inspirée de **WhatsApp**.

## ✨ Fonctionnalités

- **Clients avec photo** (appareil photo ou galerie), initiales colorées si pas de photo, photo en plein écran au toucher
- **Liste façon WhatsApp** : dernière opération, date, et pastille de solde (🔴 dette · 🟢 à jour · 🔵 avance)
- **Tableau de bord** : total à recevoir, nombre de clients en dette
- **Recherche** par nom ou téléphone, filtres *Tous / En dette / À jour*
- **Fiche client = conversation** :
  - 🛒 achats à gauche, 💵 paiements à droite, séparateurs *Aujourd'hui / Hier / date*
  - chaque bulle montre le montant, les articles, l'heure et **le reste à payer** après l'opération
  - barre de solde en haut : reste à payer, total des achats, total payé, barre de progression
- **Saisie rapide** : boutons +500, +1 000, +5 000…, bouton **« Tout payer »**, choix de la date
- Appui long sur une bulle → **modifier / supprimer** l'opération
- 📞 **Appeler** le client et 🔔 **rappel WhatsApp** pré-rempli avec son solde
- Thème clair et sombre automatiques, tout en français, montants en **FCFA**
- Données enregistrées **sur le téléphone** (SQLite) : fonctionne sans internet
- 🔄 **Mises à jour automatiques** : au démarrage, l'application vérifie s'il existe une nouvelle version sur GitHub et propose de l'installer (menu ⋮ → *Vérifier les mises à jour*)
- Icône personnalisée (carnet + pièce)

## 📦 Obtenir l'APK avec GitHub (sans rien installer)

1. Crée un dépôt sur GitHub, puis envoie ce dossier :
   ```bash
   git init
   git add .
   git commit -m "Carnet de Dettes v1"
   git branch -M main
   git remote add origin https://github.com/TON-PSEUDO/carnet-dettes.git
   git push -u origin main
   ```
2. Va dans l'onglet **Actions** du dépôt : le workflow **Build APK** se lance tout seul (≈ 5 à 8 min).
3. Ouvre l'exécution terminée → section **Artifacts** → télécharge **carnet-dettes-apk** (un .zip contenant l'APK).
4. L'APK est aussi publié automatiquement dans l'onglet **Releases** (lien direct : `https://github.com/syllapro888/carnet-dettes/releases/latest/download/carnet-dettes.apk`).

> Sur le téléphone, autorise « Installer des applications inconnues » pour installer l'APK.

## 💻 Développer en local

```bash
flutter create . --project-name carnet_dettes --org com.carnetdettes --platforms android   # une seule fois
flutter pub get
flutter run                 # sur un téléphone branché ou un émulateur
flutter build apk --release # APK dans build/app/outputs/flutter-apk/
```

Après le `flutter create`, tu peux ajouter le dossier `android/` au dépôt : le workflow l'utilisera tel quel.

## 🗂️ Structure

```
lib/
├── main.dart                       # démarrage, thème, français
├── theme.dart                      # couleurs façon WhatsApp
├── data/db.dart                    # modèles Client / Tx + base SQLite
├── utils/format.dart               # FCFA, dates, numéros WhatsApp
├── widgets/common.dart             # avatar, pastille de solde, dialogues
├── widgets/tx_sheet.dart           # saisie achat / paiement
└── screens/
    ├── home_screen.dart            # liste des clients + tableau de bord
    ├── client_form_screen.dart     # créer / modifier un client (photo)
    └── client_chat_screen.dart     # historique façon conversation
```

## ⚙️ Personnaliser

Dans `lib/utils/format.dart` :
- `kCurrency` : la monnaie affichée (`FCFA` par défaut)
- `kDefaultCountryCode` : indicatif ajouté aux numéros pour WhatsApp (`242` = Congo-Brazzaville ; mets `225` pour la Côte d'Ivoire, `223` pour le Mali, etc.)

## 🔐 Signature et mises à jour

Tous les APK sont signés avec la même clé (`signing/release.keystore`), ce qui permet d'installer chaque nouvelle version **par-dessus** l'ancienne sans perdre les données. Ne supprime pas ce fichier. Pour publier sur le Play Store, crée plutôt une clé privée stockée dans les *Secrets* GitHub ([guide officiel](https://docs.flutter.dev/deployment/android#signing-the-app)).

Chaque `git push` sur `main` crée une Release `v1.0.N` ; l'application installée la détecte toute seule.

## 🚀 Idées pour la suite

Sauvegarde/restauration (export vers Google Drive), code PIN, export PDF du relevé d'un client, statistiques par mois.
