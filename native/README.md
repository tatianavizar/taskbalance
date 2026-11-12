# Applications iOS et Android (Hotwire Native)

Deux coquilles natives autour de l'app Rails : tous les écrans restent des vues Rails, les coquilles apportent la barre d'onglets, les modales, les notifications push, les liens universels et quelques composants natifs (« bridge »).

> **Rien ici n'a été compilé ni lancé.** Le code a été écrit sans Xcode ni Android Studio, sans accès réseau (décision du 2026-11-13). Il est volontairement simple, mais attendez-vous à quelques corrections d'API à la première compilation. Les points douteux sont listés en bas de ce fichier.

```
native/
  ios/        Swift, Hotwire Native iOS 1.2 (SPM), Firebase Messaging ; projet décrit par project.yml (XcodeGen)
  android/    Kotlin, Gradle (Kotlin DSL), Hotwire Native Android 1.2, Firebase Messaging
```

## Ce que font les coquilles

| | iOS | Android |
|---|---|---|
| 4 onglets (Accueil `/dashboard`, Tâches `/chores`, Bilan `/bilan`, Foyer `/foyer`), une pile par onglet | `MainTabBarController.swift` | `MainActivity.kt`, `res/menu/tabs.xml` |
| Configuration des chemins : copie embarquée + `/configurations/{ios,android}_v1.json` | `Resources/path-configuration.json` | `assets/json/configuration.json` |
| Autorisation des notifications, jeton FCM | `PushManager.swift` | `push/PushPermission.kt`, `push/CinquanteMessagingService.kt` |
| Toucher une notification ouvre `/notifications/:id` (marque lu, redirige vers l'écran) | `PushManager` → `SceneDelegate` | `MainActivity` (extra `path`) |
| Liens universels / App Links (invitation, mot de passe, confirmation, boutons des emails) | `FiftyFifty.entitlements`, `SceneDelegate` | `AndroidManifest.xml` (`autoVerify`) |
| Composants bridge | `Bridge/*.swift` | `bridge/Components.kt` |
| Erreur de chargement (hors ligne, serveur en panne) : écran d'erreur de la bibliothèque avec « Réessayer » | par défaut | par défaut |
| Icône et écran de lancement : provisoires (cercle partagé sur menthe) | `Assets.xcassets` | `mipmap-anydpi-v26`, thème splash |

Composants bridge (le côté web est dans `app/javascript/controllers/bridge/` et `app/javascript/native_bridge.js`) :

| Nom | Où | Échange |
|---|---|---|
| `push-notifications` | layout (personne connectée, mode `sync`), H1 (mode `ask`) | `connect` / `request` → `{ permission, token, platform, previousToken }` |
| `settings` | H1, après un refus | `open` → réglages de l'app dans le téléphone |
| `date-picker` | chaque `f.field ..., as: :date` (pauses F6) | `show { value, min, max }` → `{ value }` |
| `overflow-menu` | « ⋯ » du journal (E6) | `show { title, items }` → `{ selectedIndex }` |
| `confirm` | tout `data-turbo-confirm` | `show { message, confirmLabel, cancelLabel }` → `{ confirmed }` |

Côté serveur (déjà fait et testé) : `PushDevice`, `POST/DELETE /appareils`, `Notifications::Channels::Push` (FCM HTTP v1, repli email), H1 `/notifications/autoriser`, `/.well-known/apple-app-site-association`, `/.well-known/assetlinks.json`, `/foyer`. Voir la section « Push et applications natives » de `CLAUDE.md`.

## 1. Firebase (une fois, pour les deux plateformes)

Le serveur envoie tout par Firebase Cloud Messaging ; FCM relaie vers APNs pour iOS.

1. Créer un projet sur https://console.firebase.google.com.
2. **iOS :** ajouter une app iOS, identifiant `app.cinquante.mobile`. Télécharger `GoogleService-Info.plist` et le poser dans `native/ios/FiftyFifty/Resources/` (ignoré par git).
3. **APNs :** sur https://developer.apple.com, Certificates, Identifiers & Profiles › Keys : créer une clé avec « Apple Push Notifications service (APNs) », télécharger le `.p8`. Dans Firebase › Paramètres du projet › Cloud Messaging › app iOS : téléverser la clé, avec son Key ID et le Team ID.
4. **Android :** ajouter une app Android, package `app.cinquante.mobile`. Télécharger `google-services.json` dans `native/android/app/` (ignoré par git ; sans lui, la compilation Android échoue).
5. **Serveur :** Paramètres du projet › Comptes de service › « Générer une nouvelle clé privée ». Donner le JSON au serveur, au choix :
   - `FCM_CREDENTIALS_JSON` = le contenu du fichier (secret Kamal, `.kamal/secrets`) ;
   - `FCM_CREDENTIALS_PATH` = un chemin vers le fichier ;
   - `bin/rails credentials:edit` → `fcm: { project_id: ..., client_email: ..., private_key: ... }`.
   `FCM_PROJECT_ID` remplace l'identifiant du projet si besoin. **Sans ces identifiants, le push est coupé et tout part par email** (rien ne casse).
6. Les jetons sont chiffrés en base (Active Record encryption) : les clés `ACTIVE_RECORD_ENCRYPTION_*` doivent être posées en production (déjà requis par le back-office).

## 2. iOS

Prérequis : un Mac avec Xcode 16 ou plus, un compte Apple Developer (99 €/an), XcodeGen (`brew install xcodegen`).

1. `cd native/ios && xcodegen generate` → `FiftyFifty.xcodeproj` (non versionné ; à relancer après avoir ajouté ou supprimé un fichier).
2. Ouvrir le projet. Xcode résout les paquets Swift (hotwire-native-ios ≥ 1.2.0, firebase-ios-sdk ≥ 11.0.0).
3. Target FiftyFifty › Signing & Capabilities : choisir l'équipe (ou remplir `DEVELOPMENT_TEAM` dans `project.yml`). Vérifier que les capacités Push Notifications, Background Modes (Remote notifications) et Associated Domains sont là (elles viennent de `FiftyFifty.entitlements` et `Info.plist`).
4. Lancer sur le simulateur : en Debug, l'app ouvre `http://localhost:3000` (`bin/dev` sur le Mac). Le push ne marche **pas** dans le simulateur pour un vrai envoi FCM : il faut un iPhone.
5. Sur un iPhone : en Debug, remplacer `BASE_URL` (project.yml, config Debug) par l'adresse du Mac sur le réseau local (`http://192.168.x.y:3000`) et lancer `bin/rails server -b 0.0.0.0`, ou pointer vers un serveur de recette en HTTPS.
6. TestFlight : Product › Archive, puis Distribute App › App Store Connect. Créer d'abord la fiche de l'app dans App Store Connect (identifiant `app.cinquante.mobile`).

## 3. Android

Prérequis : Android Studio (Ladybug ou plus récent), JDK 17.

1. Ouvrir `native/android` dans Android Studio. Le wrapper Gradle (binaire) n'est pas versionné : laisser Android Studio le créer, ou `gradle wrapper --gradle-version 8.10.2`.
2. Poser `app/google-services.json` (étape 1.4).
3. Lancer sur l'émulateur : en debug, l'app ouvre `http://10.0.2.2:3000` (le `bin/dev` du Mac ; le trafic en clair n'est autorisé que vers 10.0.2.2, `res/xml/network_security_config.xml`). Sur un vrai téléphone : changer `BASE_URL` du build debug (`app/build.gradle.kts`) et ajouter son adresse au fichier de sécurité réseau, ou utiliser un serveur de recette en HTTPS.
4. Release : créer une clé d'envoi (upload key), activer Play App Signing dans la Play Console, ajouter un `signingConfig` dans `app/build.gradle.kts` (commentaire en place ; mots de passe hors dépôt, `keystore.properties` est ignoré). `./gradlew bundleRelease` → `.aab` à téléverser en test interne.

## 4. Liens universels et App Links

Le serveur sert déjà les deux fichiers ; il manque les identifiants :

| Variable (serveur) | Valeur | Où la trouver |
|---|---|---|
| `APPLE_TEAM_ID` | 10 caractères | developer.apple.com › Membership |
| `IOS_BUNDLE_ID` | `app.cinquante.mobile` (défaut) | |
| `ANDROID_PACKAGE` | `app.cinquante.mobile` (défaut) | |
| `ANDROID_CERT_FINGERPRINTS` | empreintes SHA-256, séparées par des virgules | Play Console › Intégrité de l'app › Signature (clé de signature **et** clé d'envoi) ; en local `keytool -list -v -keystore ...` |

Tant qu'elles manquent, les fichiers portent `TEAMID0000` et une empreinte de zéros : valides, mais aucune app ne peut ouvrir les liens.

Vérifier après déploiement :
- `curl -i https://cinquante.app/.well-known/apple-app-site-association` (JSON, 200, sans redirection) ; Apple le lit via son CDN, ce qui peut prendre un moment après une installation ;
- `curl -i https://cinquante.app/.well-known/assetlinks.json`, puis sur le téléphone `adb shell pm verify-app-links --re-verify app.cinquante.mobile` et `adb shell pm get-app-links app.cinquante.mobile`.

Le domaine `cinquante.app` est écrit en dur à deux endroits, à changer si `APP_HOST` est différent : `native/ios/FiftyFifty/FiftyFifty.entitlements` et `native/android/app/src/main/AndroidManifest.xml` (filtre `autoVerify`). Les chemins ouverts par l'app sont dans `NativeApp::LINK_PATHS` (serveur) et dans le manifeste Android : les garder alignés. La désinscription en un clic (`/desinscription/...`) reste dans le navigateur.

## 5. Essais sur appareil (à faire)

1. Première ouverture : l'intro I1 à I3, puis H1 « Les notifications sur ce téléphone ». « Plus tard » et « Activer » mènent à l'inscription ; « Activer » montre d'abord la demande du système.
2. Après l'inscription ou la connexion : une ligne apparaît dans `push_devices` (console Rails : `PushDevice.last`).
3. Envoyer un événement (par exemple une tâche assignée par l'autre membre) : la notification arrive sur le téléphone, pas par email (`Notification.last.channel == "push"`). La toucher ouvre l'écran des tâches.
4. Refuser les notifications dans les réglages du téléphone, rouvrir l'app : la ligne `push_devices` disparaît et les messages repartent par email.
5. Se déconnecter (Mon compte) : la ligne de ce téléphone disparaît.
6. Ouvrir un lien d'invitation reçu par email sur le téléphone : il s'ouvre dans l'app.
7. Formulaire de pause (F6) : le sélecteur de date est natif. Journal (E6) : « ⋯ » ouvre un menu natif. Supprimer un enregistrement : l'écran de confirmation s'ouvre en feuille.
8. Mode avion : l'écran d'erreur de la bibliothèque s'affiche avec « Réessayer ».

## 6. Ce qui reste à faire (lot 9 et 10)

- Les vraies icônes, l'écran de lancement définitif, les captures et fiches des stores.
- Session expirée (G5) en modale : non configurée. Aujourd'hui Devise redirige vers la connexion dans l'onglet courant. Une règle `"/users/sign_in$" → context: modal` dans `ConfigurationsController` est la piste, à essayer sur appareil.
- Bandeau hors ligne côté web (G1) : seul l'écran d'erreur natif existe.
- Tirer pour rafraîchir : activé par la configuration des chemins sur les écrans par défaut, à vérifier.

## 7. Points incertains (à vérifier à la première compilation)

Versions supposées : hotwire-native-ios 1.2.0, firebase-ios-sdk 11.x, iOS 16 minimum ; Android Gradle Plugin 8.7.3, Kotlin 2.0.21, Gradle 8.10.2, `dev.hotwire:core` et `dev.hotwire:navigation-fragments` 1.2.0, firebase-bom 33.7.0, compileSdk 35, minSdk 28.

**iOS**
- `Navigator(configuration: .init(name:startLocation:))` et `navigator.start()` : API de la 1.2. En 1.0/1.1 c'était `Navigator()` + `navigator.route(url)`.
- `PathConfiguration.Source` (`.file`, `.server`), `Hotwire.loadPathConfiguration(from:)`, `Hotwire.registerBridgeComponents`, `Hotwire.config.applicationUserAgentPrefix`, `.backButtonDisplayMode`, `.showDoneButtonOnModals`, `.debugLoggingEnabled`.
- `BridgeComponent` : `override class var name`, `onReceive(message:)`, `message.data()` générique, `reply(to:with:)`. L'appel passe par `answer(_:with:)` (`Bridge/BridgeHelpers.swift`), écrit `try? await` pour compiler que la méthode soit synchrone ou asynchrone ; au pire un avertissement.
- La 1.2 propose aussi `HotwireTabBarController` / `HotwireTab` ; ce code fait sa propre barre d'onglets (`UITabBarController` + un `Navigator` par onglet), plus sûre à compiler. On peut basculer ensuite.
- `SWIFT_VERSION: 5.0` (mode Swift 5) pour éviter les erreurs de concurrence stricte de Swift 6 sur le code des délégués.

**Android**
- `Hotwire.config.applicationUserAgentPrefix`, `.jsonConverter`, `.debugLoggingEnabled`, `.webViewDebuggingEnabled` ; `Hotwire.loadPathConfiguration(context, PathConfiguration.Location(assetFilePath, remoteFileUrl))` (import `dev.hotwire.core.turbo.config.PathConfiguration`) ; `KotlinXJsonConverter` (`dev.hotwire.core.bridge`).
- `BridgeComponent<HotwireDestination>(name, delegate)` : `bridgeDelegate.destination.fragment`, `replyTo(event, jsonData)`, `message.data<T>()`.
- `HotwireActivity` : `navigatorConfigurations()`, `delegate.setCurrentNavigator(...)`, `delegate.currentNavigator?.route(url)` et `?.clearAll()` (second toucher sur l'onglet courant, le plus douteux) ; `NavigatorConfiguration(name, startLocation, navigatorHostId)` ; `dev.hotwire.navigation.navigator.NavigatorHost`.
- Les `uri` de la configuration des chemins : `hotwire://fragment/web` et `hotwire://fragment/web/modal/sheet` (le serveur les envoie aussi dans `android_v1.json`).

**Web (pont)**
- `app/javascript/native_bridge.js` réécrit le protocole de `@hotwired/hotwire-native-bridge` 1.x (le paquet n'a pas pu être téléchargé) : `window.HotwireNative.web`, évènement `web-bridge:ready`, `setAdapter`, `receive`. Si les composants ne répondent pas dans l'app, remplacer par le paquet officiel : `bin/importmap pin @hotwired/hotwire-native-bridge`, puis importer `BridgeComponent` depuis `@hotwired/hotwire-native-bridge` dans `app/javascript/controllers/bridge/*.js` (et `bridge` / `supportsComponent` dans `confirm_dialog.js`).

## 8. Espaces à remplir (récapitulatif)

| Fichier | Quoi |
|---|---|
| `native/ios/project.yml` | `DEVELOPMENT_TEAM` ; `BASE_URL` (Release et Debug) |
| `native/ios/FiftyFifty/Resources/GoogleService-Info.plist` | à télécharger (Firebase) |
| `native/ios/FiftyFifty/FiftyFifty.entitlements` | domaine `cinquante.app` si différent |
| `native/ios/FiftyFifty/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | icône provisoire (1024 × 1024, sans transparence) |
| `native/android/app/google-services.json` | à télécharger (Firebase) |
| `native/android/app/build.gradle.kts` | `BASE_URL` (release et debug), `signingConfig` |
| `native/android/app/src/main/AndroidManifest.xml` | domaine `cinquante.app` si différent |
| `native/android/app/src/main/res/drawable/ic_launcher_foreground.xml`, `ic_notification.xml` | icônes provisoires |
| Serveur (ENV) | `FCM_CREDENTIALS_JSON` (ou `_PATH`, ou credentials `fcm`), `APPLE_TEAM_ID`, `ANDROID_CERT_FINGERPRINTS`, éventuellement `IOS_BUNDLE_ID`, `ANDROID_PACKAGE`, `FCM_PROJECT_ID` |
