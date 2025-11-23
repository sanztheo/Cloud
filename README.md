<div align="center">
  <img src="assets/banner.png" alt="Cloud Browser Banner" width="100%">

  <h1>☁️ Cloud Browser</h1>
  <p><strong>Un navigateur web moderne pour macOS, inspiré par Arc</strong></p>

  ![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
  ![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)
  ![SwiftUI](https://img.shields.io/badge/SwiftUI-Yes-green.svg)
  ![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-orange.svg)
</div>

---

## ✨ Fonctionnalités

### 🎯 Navigation Intelligente
- **Spotlight Search** - Recherche rapide style macOS avec suggestions intelligentes
- **Smart Autocomplete** - Fuzzy matching + scoring frecency (fréquence × récence)
- **Inline Autocomplete** - Suggestions URL en temps réel (tapez "linke" → "linkedin.com")
- **Focus permanent** - Le champ de recherche reste toujours accessible (style Arc)
- **Navigation fluide** - WebKit optimisé pour des performances maximales

### 🗂️ Organisation
- **Spaces** - Organisez vos onglets par contexte (Personnel, Travail, etc.)
- **Folders** - Groupez vos onglets dans des dossiers (drag & drop, style Arc)
- **Onglets épinglés** - Sites favoris protégés (Ctrl+W ne les ferme pas)
- **Onglets protégés** - Les onglets dans folders sont protégés de la fermeture accidentelle
- **Thèmes personnalisables** - Mode Light/Dark par Space avec couleurs personnalisées
- **Sidebar dynamique** - Accès rapide à vos onglets avec favicons automatiques
- **Persistance complète** - Spaces, folders et onglets sauvegardés automatiquement

### 🤖 IA Intégrée
- **Summarize Page** - Résumez n'importe quelle page web avec l'IA (OpenAI)
- **Ask About WebPage** - Posez des questions à l'IA sur la page actuelle
- **Streaming en temps réel** - Voir la réponse s'écrire en direct
- **Multi-langues** - Choisissez la langue du résumé (FR, EN, ES, DE, IT, JP, CN)
- **Cache intelligent** - Les résumés sont mis en cache pour un accès instantané
- **Animation de flottement** - La WebView flotte pendant la génération

### 🎨 Interface
- **Design minimal** - Interface épurée sans barre supérieure (style Arc)
- **Animations fluides** - Transitions douces et naturelles avec Spring animations
- **Thèmes adaptatifs** - Interface qui s'adapte au thème du Space actif
- **Traffic lights personnalisés** - Boutons de fenêtre intégrés à la sidebar

### 📥 Gestionnaire de Téléchargements
- **Téléchargements natifs** - Support complet des téléchargements via WebKit
- **Progression en temps réel** - Barre de progression et pourcentage en live
- **Aperçu des images** - Miniatures pour les fichiers images téléchargés
- **Notifications** - Badge de notification sur l'icône Downloads
- **Annulation facile** - Survolez le spinner pour annuler un téléchargement
- **Gestion des fichiers** - Ouvrir, révéler dans Finder, supprimer

### ⚡ Performance
- **WebKit optimisé** - Configuration WebKit personnalisée pour plus de rapidité
- **Chargement asynchrone** - Favicons et ressources chargés en arrière-plan
- **Gestion mémoire** - Optimisation des ressources système

---

## 🚀 Installation

### Prérequis
- macOS 13.0 (Ventura) ou supérieur
- Xcode 15.0+
- Swift 5.9+

### Build depuis les sources
```bash
# Cloner le repository
git clone https://github.com/votre-username/cloud-browser.git
cd cloud-browser

# Ouvrir dans Xcode
open Cloud.xcodeproj

# Build et Run
⌘ + R
```

### Configuration de l'IA
1. Ouvrir les paramètres (`⌘ + ,`)
2. Entrer votre clé API OpenAI
3. Sélectionner la langue souhaitée pour les résumés

---

## ⌨️ Raccourcis clavier

| Raccourci | Action |
|-----------|--------|
| `⌘ + T` | Ouvrir Spotlight / Nouvel onglet |
| `⌘ + W` | Fermer l'onglet |
| `⌘ + S` | Toggle Sidebar |
| `⌘ + ,` | Paramètres |
| `⌘ + [` | Page précédente |
| `⌘ + ]` | Page suivante |
| `⌘ + R` | Recharger la page |
| `⌘ + 1-9` | Accès rapide aux onglets |
| `Escape` | Fermer Spotlight / Annuler résumé |

---

## 🏗️ Architecture

Le projet est structuré en architecture MVVM avec SwiftUI:

```
Cloud/
├── Models/          # Modèles de données (Tab, Space, Bookmark, Folder, SpaceTheme)
├── ViewModels/      # Logique métier (BrowserViewModel)
├── Views/           # Interface SwiftUI
│   ├── BrowserView.swift
│   ├── SummaryView.swift
│   ├── SidebarView.swift
│   ├── Components/
│   │   └── FolderRowView.swift
│   └── Spotlight/   # Spotlight avec autocomplete intelligent
├── Services/        # Services utilitaires
│   ├── OpenAIService.swift
│   ├── SummaryCacheService.swift
│   └── OptimizedWebKitConfig.swift
├── Utilities/       # Utilitaires
│   └── FrecencyCalculator.swift
├── Extensions/      # Extensions Swift
│   └── Color+Hex.swift
└── Resources/       # Assets et configurations
```

---

## 🔧 Technologies utilisées

- **SwiftUI** - Framework UI déclaratif
- **WebKit** - Moteur de rendu web
- **Combine** - Programmation réactive
- **AppKit** - Intégration système macOS
- **OpenAI API** - Génération de résumés IA

---

## 🎯 Roadmap

- [x] Summarize Page avec IA
- [x] Ask About WebPage (questions à l'IA)
- [x] Thèmes personnalisables par Space
- [x] Persistance des Spaces
- [x] Multi-langues pour les résumés
- [x] Gestionnaire de téléchargements avec progression en temps réel
- [x] Historique de navigation avec recherche et filtres
- [x] Folders pour organiser les onglets (style Arc)
- [x] Smart Autocomplete avec fuzzy matching et frecency
- [x] Inline autocomplete pour les URLs
- [x] Onglets protégés (pinnés et dans folders)
- [ ] Synchronisation iCloud
- [ ] Extensions de navigateur
- [ ] Profils utilisateurs
- [ ] Mode lecture
- [ ] Collections de signets intelligentes

---

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📝 License

Ce projet est sous licence **[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)**.

| Autorisé | Interdit |
|----------|----------|
| ✅ Partager (non-commercial) | ❌ Usage commercial |
| ✅ Contribuer via PR | ❌ Créer un fork commercial |
| ✅ Modifier (même licence) | ❌ Changer la licence |

**Contributions:** En soumettant une PR, vous acceptez le [CLA](CONTRIBUTING.md#accord-de-licence-cla).

📧 **Contact pour licence commerciale:** sanztheopro@gmail.com

Voir les fichiers `LICENSE` et `CONTRIBUTING.md` pour plus de détails.

---

## 👨‍💻 Auteur

**Sanz**

- GitHub: [@sanztheo](https://github.com/sanztheo)

---

## 🙏 Remerciements

- Inspiré par [Arc Browser](https://arc.net)
- Icônes de [SF Symbols](https://developer.apple.com/sf-symbols/)
- Communauté Swift et SwiftUI

---

<div align="center">
  <p>Fait avec ❤️ pour macOS</p>
  <p>⭐ Si vous aimez ce projet, n'hésitez pas à lui donner une étoile !</p>
</div>
