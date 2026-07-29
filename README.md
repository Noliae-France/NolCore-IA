# NolCore IA

Service public Nolc d’agrégation des fournisseurs IA : Claude, ChatGPT, Mistral et Gemini.

Les tokens API sont exclusivement injectés par l’environnement, un Secret Kubernetes ou un coffre-fort. Aucun secret n’est présent dans ce dépôt.

## Contrat

- POST /v1/ia/:nameid/:modelia/:text
- GET /v1/search/ia/:keyword

Le service est conçu pour être déployé indépendamment du gateway API.
