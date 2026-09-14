# Squeak

Fermez les applications et l’onglet actif que vous avez sélectionnés avec **P + Suppr**.

## Télécharger et installer

### Windows x64

[Télécharger Squeak pour Windows](downloads/Squeak-Windows.zip?raw=true)

1. Extraire entièrement le ZIP.
2. Ouvrir le dossier extrait et lancer **Installer Squeak.bat**.
3. Autoriser la demande administrateur Windows pour le certificat local Squeak et son menu contextuel.

L’application, le moteur AutoHotkey et l’intégration au clic droit sont installés ensemble. Sur Windows 11, **Intégrer à Squeak** apparaît dans le menu principal des programmes et raccourcis compatibles. Sur Windows 10, l’intégration utilise le menu classique.

Le paquet du menu est signé avec un certificat local Squeak, pas avec une signature commerciale reconnue publiquement. L’installateur ajoute ce certificat au magasin Windows `TrustedPeople` de la machine, après validation administrateur. Des avertissements Windows peuvent apparaître. Une installation sur un PC vierge reste à valider.

La liste initiale est vide. Ajoutez vos propres programmes et sites, cochez-les, maintenez **P** puis appuyez sur **Suppr**. Pour un site, son onglet doit être au premier plan. Les applications qui demandent une sauvegarde ou restent en arrière-plan ne sont pas arrêtées de force par défaut.

L’extension Chrome/Edge est incluse, mais son activation dans chaque navigateur reste manuelle : voir `windows/browser-extension/INSTALLATION.txt`.

### macOS — expérimental, sources uniquement

[Télécharger les sources macOS](downloads/Squeak-macOS-sources.zip?raw=true)

**Compilation macOS et tests automatiques validés sur GitHub Actions. Les essais interactifs dans Chrome/Edge et le Finder restent à effectuer : cette version reste expérimentale.**

Elle nécessite macOS 12 ou ultérieur et les outils de développement Apple. Dans Terminal, depuis le dossier extrait :

```bash
bash "Installer Squeak.command"
```

Le script compile l’application dans `~/Applications` et inscrit son service **Services → Intégrer à Squeak** dans le Finder. macOS peut nécessiter l’activation du service et des autorisations Accessibilité et Automatisation. La signature Apple Developer ID, la notarisation et les tests Intel/Apple Silicon restent à réaliser avant une diffusion générale.

La liaison **Chrome et Edge pour macOS** est incluse et enregistrée automatiquement pendant l’installation. Chargez ensuite `macos/browser-extension` dans chaque navigateur : [instructions macOS](macos/browser-extension/INSTALLATION.txt). Elle permet d’ajouter un site ou une page exacte et de vérifier son état dans Squeak. Safari n’est pas couvert par cette extension.

## Contenu

- `downloads/` : archives à télécharger.
- `windows/` : fichiers d’installation Windows, moteur et menu signé.
- `macos/` : sources natives et script d’installation expérimental.
- `sources-windows/` : sources de l’extension native et de la liaison navigateur.

Aucune liste personnelle, configuration utilisateur ou clé privée de signature n’est publiée. Le fichier `.cer` est le **certificat public** nécessaire à l’installation du menu.

AutoHotkey 2.0.26 est fourni avec sa licence et ses sources dans `windows/runtime/`. Les tests Windows de l’application et de la commande native passent ; la validation complète sur un nouveau PC reste à effectuer.
