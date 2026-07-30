<div align="center">

# ◈ NolCore IA

### Agrégateur multi-fournisseurs de Noliae, natif en Nolc

[![CI](https://github.com/Noliae-France/NolCore-IA/actions/workflows/ci.yml/badge.svg)](https://github.com/Noliae-France/NolCore-IA/actions/workflows/ci.yml)
[![Container](https://github.com/Noliae-France/NolCore-IA/actions/workflows/container.yml/badge.svg)](https://github.com/Noliae-France/NolCore-IA/actions/workflows/container.yml)
[![Runtime](https://img.shields.io/badge/runtime-Nolc-ff4d2e)](https://github.com/Noliae-France/nolc)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-2ea44f)](LICENSE)

</div>

## Objectif

NolCore-IA centralise les appels aux fournisseurs IA sans exposer leurs tokens
au navigateur, au gateway ou à PostgreSQL. Il reçoit une requête normalisée,
appelle le fournisseur demandé et renvoie une enveloppe contenant la réponse
fournisseur, les compteurs de tokens disponibles et un coût estimé.

Fournisseurs supportés : **Claude**, **ChatGPT/OpenAI**, **Mistral** et
**Gemini**.

```text
Client → NolCore-API → NolCore-IA → fournisseur IA
                       réseau interne     token secret
```

Le service ne possède ni comptes, ni permissions, ni base de données. Ces
contrôles sont assurés par
[NolCore-API](https://github.com/Noliae-France/NolCore-API), qui est le seul
point d’entrée public.

## Contrat HTTP

Le service écoute par défaut sur le port `8092`.

| Méthode | Route | Corps / description |
|---|---|---|
| `GET` | `/api/health` | Liveness et readiness probe |
| `GET` | `/v1/ia/models` | Catalogue live des modèles OpenAI, Mistral et Gemini configurés |
| `POST` | `/v1/ia` | `{"provider":"mistral","model":"...","text":"..."}` |
| `POST` | `/v1/ia/:nameid/:modelia/:text` | Variante avec paramètres de route |

Réponse type :

```json
{
  "provider": "mistral",
  "model": "…",
  "input_tokens": 120,
  "output_tokens": 64,
  "estimated_cost_micros": 0,
  "result": "réponse brute du fournisseur"
}
```

Les requêtes invalides retournent `400` ou `422`, un token absent `503` et une
erreur fournisseur `502`. Le catalogue live est volontairement best-effort :
un fournisseur indisponible est absent de la liste, sans révéler son token.

## Configuration fournisseurs

Chaque fournisseur utilise deux variables. L’URL est facultative : une URL
officielle est sélectionnée par défaut pour les fournisseurs connus.

| Fournisseur | Token | URL personnalisée |
|---|---|---|
| Claude | `NOLCORE_CLAUDE_TOKEN` | `NOLCORE_CLAUDE_URL` |
| ChatGPT/OpenAI | `NOLCORE_CHATGPT_TOKEN` | `NOLCORE_CHATGPT_URL` |
| Mistral | `NOLCORE_MISTRAL_TOKEN` | `NOLCORE_MISTRAL_URL` |
| Gemini | `NOLCORE_GEMINI_TOKEN` | `NOLCORE_GEMINI_URL` |

Pour le catalogue live, les URL de catalogue peuvent être surchargées avec
`NOLCORE_CHATGPT_MODELS_URL`, `NOLCORE_MISTRAL_MODELS_URL` et
`NOLCORE_GEMINI_MODELS_URL`. Claude n’expose pas de catalogue général
équivalent dans ce service ; ses modèles sont configurés explicitement côté
Core.

Le coût est un calcul local, basé sur les tokens retournés par le fournisseur :

| Variable | Rôle |
|---|---|
| `NOLCORE_<PROVIDER>_INPUT_MICROS_PER_1K` | Prix d’entrée en micro-unités pour 1 000 tokens |
| `NOLCORE_<PROVIDER>_OUTPUT_MICROS_PER_1K` | Prix de sortie en micro-unités pour 1 000 tokens |

Par exemple, utilisez `NOLCORE_MISTRAL_INPUT_MICROS_PER_1K` et
`NOLCORE_MISTRAL_OUTPUT_MICROS_PER_1K`. À `0`, le coût reste inconnu : aucun
prix fictif n’est affiché.

`NOLIAE_PORT` permet de modifier le port d’écoute (`8092` par défaut).

Ne commitez jamais ces tokens. Injectez-les via Compose, un Secret Kubernetes,
External Secrets ou un coffre-fort.

## Démarrage local

```sh
git clone https://github.com/Noliae-France/NolCore-IA.git
cd NolCore-IA
docker build -t nolcore-ia .
docker run --rm -p 8092:8092 \
  -e NOLCORE_MISTRAL_TOKEN='votre-token' \
  nolcore-ia
```

```sh
curl http://localhost:8092/api/health
curl -X POST http://localhost:8092/v1/ia \
  -H 'content-type: application/json' \
  -d '{"provider":"mistral","model":"mistral-small-latest","text":"Bonjour"}'
```

## Kubernetes / K3s

Le fichier `deploy.yaml` définit deux réplicas et un Service interne :

```sh
kubectl -n nolcore create secret generic nolcore-ia-secrets \
  --from-literal=NOLCORE_MISTRAL_TOKEN='votre-token'
kubectl apply -f deploy.yaml
kubectl -n nolcore rollout status deployment/nolcore-ia
```

Conservez le Service sans Ingress public. NolCore-API doit l’appeler via
`http://nolcore-ia:8092` dans le cluster.

## Build, imports Nolc et CI/CD

```sh
nolc check main.nol
nolc build main.nol -o nolcore --lien ssl --lien crypto
```

Le Dockerfile télécharge le compilateur Nolc public, produit un binaire dans une
étape de build et démarre le runtime sous un utilisateur non-root. Les imports
Nolc historiques `../nolc/lib/*` et versionnés `vendor/nolc/lib/*` sont tous
deux disponibles dans l’étape de compilation ; ne les remplacez pas par
`COPY *.nol` seul.

Deux workflows GitHub Actions sont exécutés sur `main` :

- **IA CI** construit l’image sans publication ;
- **Publish IA container** publie l’image validée
  `ghcr.io/noliae-france/nolcore-ia:main`.

La vérification de la chaîne API + IA + Crawler est exécutée dans
[NolCore](https://github.com/Noliae-France/NolCore).

## Sécurité

- Le service est réservé au réseau interne.
- Les tokens fournisseurs sont seulement lus depuis l’environnement.
- Les données utilisateur et les contrôles d’accès restent dans NolCore-API.
- Aucun token, corps de requête ou coût ne doit être considéré comme un secret
  à journaliser : configurez vos logs pour ne pas conserver les prompts.
- Configurez délais, limites de sortie réseau et journalisation selon vos
  contraintes de production.

## Contrat avec les frontends

NolCore-IA n’est jamais appelé directement depuis le navigateur. Les
frontends NHTML appellent le Core avec le cookie de session ; le Core vérifie
l’identité, les droits et les quotas avant de déléguer sur le réseau interne.

## Écosystème et licence

- [NolCore](https://github.com/Noliae-France/NolCore) — stack complète et CI
  d’intégration.
- [NolCore-API](https://github.com/Noliae-France/NolCore-API) — gateway public.
- [NolCore-Crawler](https://github.com/Noliae-France/NolCore-Crawler) — crawl
  respectueux de `robots.txt`.

Distribué sous [licence MIT](LICENSE).
