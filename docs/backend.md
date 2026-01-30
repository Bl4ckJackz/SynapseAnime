# Backend Documentation

## Moduli

- **auth/** - Autenticazione JWT
- **anime/** - Catalogo anime e episodi
- **users/** - Profili, watchlist, history
- **ai/** - Raccomandazioni AI
- **notifications/** - Push notifications FCM

## Setup Database

Il progetto usa PostgreSQL via Docker:

```bash
docker-compose up -d
```

## API Documentation

Swagger UI disponibile su `/api/docs` dopo l'avvio del server.
