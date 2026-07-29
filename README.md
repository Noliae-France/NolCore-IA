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
choisit le fournisseur et renvoie la réponse brute dans une enveloppe JSON.

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
| `POST` | `/v1/ia` | `{"provider":"mistral","model":"...","text":"..."}` |
| `POST` | `/v1/ia/:nameid/:modelia/:text` | Variante avec paramètres de route |

Réponse type :

```json
{
  "provider": "mistral",
  "model": "…",
  "result": "réponse brute du fournisseur"
}
```

Les requêtes invalides retournent `400` ou `422`, un token absent `503` et une
erreur fournisseur `502`.

## Configuration fournisseurs

Chaque fournisseur utilise deux variables. L’URL est facultative : une URL
officielle est sélectionnée par défaut pour les fournisseurs connus.

| Fournisseur | Token | URL personnalisée |
|---|---|---|
| Claude | `NOLCORE_CLAUDE_TOKEN` | `NOLCORE_CLAUDE_URL` |
| ChatGPT/OpenAI | `NOLCORE_CHATGPT_TOKEN` | `NOLCORE_CHATGPT_URL` |
| Mistral | `NOLCORE_MISTRAL_TOKEN` | `NOLCORE_MISTRAL_URL` |
| Gemini | `NOLCORE_GEMINI_TOKEN` | `NOLCORE_GEMINI_URL` |

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

## Développement et CI/CD

```sh
nolc check main.nol
nolc build main.nol -o nolcore --lien ssl --lien crypto
```

Le Dockerfile télécharge le compilateur Nolc public, produit un binaire dans une
étape de build et démarre le runtime sous un utilisateur non-root. La CI valide
la compilation, le conteneur et publie l’image GHCR. La vérification de la
chaîne API + IA + Crawler est exécutée dans
[NolCore](https://github.com/Noliae-France/NolCore).

## Sécurité

- Le service est réservé au réseau interne.
- Les tokens fournisseurs sont seulement lus depuis l’environnement.
- Les données utilisateur et les contrôles d’accès restent dans NolCore-API.
- Configurez délais, limites de sortie réseau et journalisation selon vos
  contraintes de production.

## Écosystème et licence

- [NolCore](https://github.com/Noliae-France/NolCore) — stack complète et CI
  d’intégration.
- [NolCore-API](https://github.com/Noliae-France/NolCore-API) — gateway public.
- [NolCore-Crawler](https://github.com/Noliae-France/NolCore-Crawler) — crawl
  respectueux de `robots.txt`.

Distribué sous [licence MIT](LICENSE).
