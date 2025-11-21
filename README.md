<div align="center">
  <img src="assets/banner.png" alt="Cloud Browser Banner" width="100%">

  <h1>☁️ Cloud Browser</h1>
  <p><strong>Un navigateur web moderne pour macOS, inspiré par Arc</strong></p>

  ![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
  ![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)
  ![SwiftUI](https://img.shields.io/badge/SwiftUI-Yes-green.svg)
  ![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)
</div>

---

## ✨ Fonctionnalités

### 🎯 Navigation Intelligente
- **Spotlight Search** - Recherche rapide style macOS avec suggestions Google prioritaires
- **Focus permanent** - Le champ de recherche reste toujours accessible (style Arc)
- **Navigation fluide** - WebKit optimisé pour des performances maximales

### 🗂️ Organisation
- **Spaces** - Organisez vos onglets par contexte (Personnel, Travail, etc.)
- **Sidebar dynamique** - Accès rapide à vos onglets avec favicons automatiques
- **Onglets épinglés** - Gardez vos sites favoris toujours accessibles

### 🎨 Interface
- **Design minimal** - Interface épurée sans barre supérieure (style Arc)
- **Animations fluides** - Transitions douces et naturelles avec Spring animations
- **Mode sombre natif** - Interface adaptée à macOS

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

---

## ⌨️ Raccourcis clavier

| Raccourci | Action |
|-----------|--------|
| `⌘ + T` | Nouvel onglet |
| `⌘ + W` | Fermer l'onglet |
| `⌘ + K` | Ouvrir Spotlight |
| `⌘ + B` | Toggle Sidebar |
| `⌘ + ←` | Page précédente |
| `⌘ + →` | Page suivante |
| `⌘ + R` | Recharger la page |
| `⌘ + L` | Focus barre d'adresse |

---

## 🏗️ Architecture

Le projet est structuré en architecture MVVM avec SwiftUI:

```
Cloud/
├── Models/          # Modèles de données (Tab, Space, Bookmark)
├── ViewModels/      # Logique métier (BrowserViewModel)
├── Views/           # Interface SwiftUI
│   ├── BrowserView.swift
│   ├── SpotlightView.swift
│   └── SidebarView.swift
├── Services/        # Services utilitaires
│   └── OptimizedWebKitConfig.swift
└── Resources/       # Assets et configurations
```

---

## 🔧 Technologies utilisées

- **SwiftUI** - Framework UI déclaratif
- **WebKit** - Moteur de rendu web
- **Combine** - Programmation réactive
- **AppKit** - Intégration système macOS

---

## 🎯 Roadmap

- [ ] Synchronisation iCloud
- [ ] Extensions de navigateur
- [ ] Profils utilisateurs
- [ ] Gestionnaire de téléchargements avancé
- [ ] Mode lecture
- [ ] Collections de signets intelligentes
- [ ] Historique de navigation amélioré

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

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

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
