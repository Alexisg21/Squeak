SQUEAK 2.2 - Windows / AutoHotkey v2

INSTALLATION
Installer-Squeak.ps1 installe une copie dans LocalAppData\Squeak, recrée
le raccourci du Bureau et le menu clic droit. Les anciennes configurations
et le raccourci remplacé sont sauvegardés dans le sous-dossier backups.
La configuration de la version migrée est conservée. Une installation neuve
démarre avec une liste vide. Aucune ancienne sélection n'est réactivée.

UTILISATION
Raccourci par défaut : P + Suppr. Maintenir P puis appuyer sur Suppr.
Le raccourci peut être modifié dans les réglages.
Fermer la fenêtre ou cliquer sur Réduire conserve Squeak dans la zone de notification.
Quitter est disponible dans le menu de l'icône de notification.

PROGRAMMES
Les programmes sont fermés normalement. Les dialogues de sauvegarde sont
respectés. Le résultat indique Fermé, Encore ouvert, Introuvable ou Échec.
Le forçage s'active séparément pour une application sélectionnée, après
confirmation du risque de perte des documents non enregistrés.
Un programme qui garde des processus en arrière-plan est indiqué Encore ouvert.

URL
Seul l'onglet du navigateur actif au déclenchement du raccourci est examiné.
Le bouton de Squeak ne ferme pas d'URL lorsque Squeak est la fenêtre active.
Les sites sont reconnus avec ou sans www ; les autres sous-domaines restent séparés.
Les pages exactes conservent leur domaine exact. Aucun parcours automatique des onglets.
Un chemin correspond à lui-même et à ses sous-chemins, en respectant la casse.
Les paramètres et fragments, lorsqu'ils sont précisés, doivent aussi correspondre.
Une perte du focus interrompt l'action. Le résultat indique Fermeture demandée,
car l'envoi de Ctrl+W ne confirme pas à lui seul que l'onglet s'est fermé.
La lecture de l'adresse utilise temporairement le presse-papiers puis le restaure.

FIABILITE
Les ajouts externes sont transmis à l'instance existante. Une seule instance
écrit la configuration. La sauvegarde utilise un fichier temporaire vérifié,
un remplacement Windows et une copie .bak. Les erreurs sont affichées.
Une configuration invalide provoque un message au démarrage, sans être écrasée.

TESTS
Test-Squeak.ps1 vérifie les URL, la normalisation, la sauvegarde, la liste vide,
les erreurs d'écriture, les ajouts concurrents et la fermeture de processus factices.
Les tests utilisent des fichiers, noms de fenêtres et mutex distincts de l'application.
Les véritables onglets du navigateur ne sont pas fermés par les tests.

INTERFACE NOIR ET OR
Menus ... : options par application. Roue dentee : raccourci clavier.
La liste affiche cinq elements par page, avec navigation en bas a droite.
Le theme est fourni dans Theme.ahk et le dossier theme.
