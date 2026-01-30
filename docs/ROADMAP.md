# 🗺️ Project Roadmap & Tasks

Questo documento contiene le task pianificate per l'evoluzione del progetto. Puoi copiare queste sezioni per creare Issue su GitHub.

## 📱 Web App Implementation
**Status:** In Progress 🚧
**Priority:** High

Sviluppo della versione Web completa per browser desktop e mobile.
- [ ] **Setup Iniziale**: Configurazione Next.js + Tailwind (Fatto).
- [ ] **Auth Integration**: Login/Register page collegata alle API NestJS.
- [ ] **Video Player**: Implementazione player custom (es. Vidstack o HTML5 nativo) con supporto HLS.
- [ ] **Search & Discover**: Pagina di ricerca con filtri avanzati (Genere, Anno, Stato).
- [ ] **Responsive Design**: Ottimizzazione layout per Mobile Web.

## 💾 Download Feature (Offline Mode)
**Status:** Planned 📋
**Priority:** Medium (Mobile Only)

Permettere agli utenti di scaricare episodi per la visione offline.
- [ ] **Download Manager**: Servizio background per gestire code di download.
- [ ] **Storage**: Gestione file system locale (criptato opzionale).
- [ ] **UI**: Pulsante download nella scheda episodio e pagina "Download" dedicata.
- [ ] **Sync**: Quando online, sincronizzare il progresso degli episodi guardati offline.

## 🎨 UI Optimization & UX
**Status:** Planned 📋
**Priority:** Medium

Migliorare l'aspetto e l'usabilità dell'app mobile e web.
- [ ] **Design System**: Standardizzare colori, typografia e spaziature.
- [ ] **Animations**: Aggiungere micro-animazioni (hero transitions, button feedback) per rendere l'app più "viva".
- [ ] **Skeleton Loaders**: Migliorare l'esperienza di caricamento dati.
- [ ] **Error Handling**: Schermate di errore user-friendly (es. "Nessuna connessione").

## ⏱️ Watch History Sync
**Status:** Started (Backend) 🔄
**Priority:** High

Sincronizzazione robusta della cronologia tra dispositivi.
- [ ] **Backend**: API per salvare/recuperare progressi puntuali (già avviato con Firebase).
- [ ] **Resume Watching**: Funzionalità "Riprendi da dove hai lasciato" in Home.
- [ ] **Auto-Sync**: Trigger salvataggio ogni 30 secondi durante la riproduzione.
- [ ] **Visual Indicators**: Progress bar sulle card degli episodi.

## 🌍 Language Support (i18n)
**Status:** Planned 📋
**Priority:** Low

Supporto multilingua per l'interfaccia utente.
- [ ] **Infrastructure**: Configurazione libreria i18n (es. `easy_localization` per Flutter, `next-intl` per Web).
- [ ] **Translations**: File JSON per le lingue target (IT, EN standard).
- [ ] **Language Switcher**: Opzione nelle impostazioni per cambiare lingua manualmente.
- [ ] **Content**: Gestione (ove possibile) dei metadati anime in lingua diversa (se supportato dalle fonti).
