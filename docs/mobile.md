# Mobile Documentation

## Architettura

Clean Architecture con separazione:

```
lib/
├── core/           # Theme, routing, constants
├── data/           # Repositories, API client
├── domain/         # Entities, business logic
└── presentation/   # Screens, widgets, providers
```

## State Management

Riverpod per gestione stato reattivo e dependency injection.

## Routing

go_router per navigazione declarativa con deep linking support.
