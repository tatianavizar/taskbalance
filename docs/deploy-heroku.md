# Déployer sur Heroku (staging, puis production)

L'app tourne sur Heroku avec le **stack conteneur** : Heroku construit le même
`Dockerfile` que Kamal (`heroku.yml`). Une app Heroku par environnement :
`cinquante-staging`, puis `cinquante-production`. Les deux tournent en
`RAILS_ENV=production`, seules leurs variables changent.

Kamal (`config/deploy.yml`) reste possible : `config/database.yml` garde ses
noms de bases quand les variables `*_DATABASE_URL` ci-dessous sont absentes.

## Ce que fait chaque déploiement

1. Heroku construit l'image depuis le `Dockerfile` (gems, Tailwind, assets).
2. **Phase de release** : `db:prepare` sur les quatre bases (charge le schéma
   d'une base vide, sinon lance les migrations), puis `db:seed` (catalogue des
   tâches, mis à jour par clé, jamais supprimé). Si elle échoue, la version
   n'est pas publiée.
3. Démarrage des process `web` (Puma sur `$PORT`) et `worker` (Solid Queue :
   moteur toutes les 15 min, emails, push).

## Créer le staging (une fois)

Prérequis : un compte Heroku avec une carte enregistrée, la CLI
(`brew install heroku/brew/heroku`), `heroku login`.

```bash
heroku create cinquante-staging --region eu --stack container
git remote rename heroku staging   # le remote créé s'appelle heroku

# Quatre bases Postgres (une par rôle, comme sous Kamal)
heroku addons:create heroku-postgresql:essential-0 -a cinquante-staging                       # DATABASE_URL
heroku addons:create heroku-postgresql:essential-0 -a cinquante-staging --as CACHE_DATABASE
heroku addons:create heroku-postgresql:essential-0 -a cinquante-staging --as QUEUE_DATABASE
heroku addons:create heroku-postgresql:essential-0 -a cinquante-staging --as CABLE_DATABASE
```

### Variables

```bash
heroku config:set -a cinquante-staging \
  RAILS_MASTER_KEY="$(cat config/master.key)" \
  APP_HOST=cinquante-staging-xxxx.herokuapp.com \
  SOLID_QUEUE_IN_PUMA=1 \
  WEB_CONCURRENCY=1
```

- `APP_HOST` : l'adresse exacte donnée par `heroku apps:info -a cinquante-staging`
  (« Web URL », sans `https://`). Sans elle, l'app refuse les requêtes
  (protection de l'en-tête Host) et les liens des emails sont faux.
- `SOLID_QUEUE_IN_PUMA=1` : en staging, les jobs tournent dans le process web,
  ce qui évite de payer le dyno `worker`. En production, l'enlever et lancer
  `heroku ps:scale worker=1`.
- **Chiffrement** (secrets TOTP des admins) : `bin/rails db:encryption:init`
  une fois, puis soit mettre les trois clés dans les credentials
  (`active_record_encryption`), soit
  `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY`,
  `..._KEY_DERIVATION_SALT`. Ne plus jamais les changer.
- **Emails** : `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USER_NAME`, `SMTP_PASSWORD`,
  `SMTP_DOMAIN`, `MAIL_FROM` (`config/initializers/00_mail.rb`). Sans eux,
  aucun email ne part (confirmation, bilan du lundi).
- **Push** (quand Firebase est prêt) : `FCM_CREDENTIALS_JSON`, `APPLE_TEAM_ID`,
  `ANDROID_CERT_FINGERPRINTS` (`native/README.md`).

### Déployer

```bash
git push staging mobile-v1:main     # Heroku déploie la branche main de son remote
heroku logs --tail -a cinquante-staging
```

### Premier superadmin

```bash
heroku run -a cinquante-staging --env "ADMIN_EMAIL=toi@exemple.fr" bin/rails admin:bootstrap
```

Le mot de passe est demandé dans le terminal ; ouvrir ensuite le lien
d'activation affiché (30 min) sur `https://<APP_HOST>/admin`.

## Coût indicatif (staging)

| Élément | Plan | ≈ par mois |
|---|---|---|
| web | Basic | 7 $ |
| 4 bases Postgres | Essential-0 | 4 × 5 $ |
| worker | aucun (`SOLID_QUEUE_IN_PUMA=1`) | 0 $ |

## Domaine (plus tard)

Quand le domaine est acheté : `heroku domains:add staging.cinquante.app`,
l'enregistrement DNS (CNAME) indiqué par Heroku, `heroku certs:auto:enable`,
puis `APP_HOST=staging.cinquante.app`. Pour les apps mobiles, l'adresse du
serveur et le domaine des liens d'app sont écrits dans `native/ios/project.yml`
(`BASE_URL`), `FiftyFifty.entitlements` et le manifeste Android
(`native/README.md`).
