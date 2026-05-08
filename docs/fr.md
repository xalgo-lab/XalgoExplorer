# XalgoExplorer

XalgoExplorer est un gestionnaire de fichiers natif pour macOS, pense pour les utilisateurs qui passent de Windows a macOS.

Il conserve des habitudes de gestion de fichiers directes et visibles, tout en respectant les conventions macOS.

## Points forts

- Espace de travail a plusieurs panneaux pour parcourir plusieurs dossiers.
- Actions familières : retour, avance, dossier parent, actualiser, nouveau dossier, nouveau fichier, couper, copier et coller.
- Glisser-deposer proche de Finder : deplacement sur le meme disque, copie entre disques differents.
- Barre laterale compacte pour dossiers courants, raccourcis utilisateur, disques montes et emplacements reseau.
- Navigation au clavier, selection a la souris et selection par zone.
- Libelles et infobulles multilingues.
- Paquet DMG pour macOS.

## Version candidate

`v0.1.1-candidate` cible Apple Silicon macOS 14 ou version ulterieure.

Telechargez le DMG depuis GitHub Releases, puis faites glisser `xAlgo Explorer.app` vers `Applications`.

## Notes de version

### v0.1.1-candidate

- Corrige les anciennes donnees de glisser-deposer interne afin qu'un glisser annule ne puisse pas deplacer le mauvais fichier plus tard.
- Ajoute une validation du renommage et rejette les entrees dangereuses comme `../file` ou `a/b`.
- Le collage d'un fichier coupe dans son dossier d'origine devient un no-op au lieu de creer un doublon.
- Ajoute la copie et le collage de fichiers compatibles Finder via le presse-papiers systeme.
- Ajoute un bouton de fermeture de recherche et la gestion de Escape afin que les fleches reviennent a la navigation dans la liste de fichiers.
- Supprime le faux appareil reseau code en dur et affiche un etat reseau vide jusqu'a l'implementation de la vraie detection.
- Met a jour les metadonnees candidates, le nom du DMG, les notes README et les tests de regression.

### v0.1.0-candidate

Premiere version candidate publique avec interface native macOS, navigation a plusieurs panneaux, glisser-deposer de fichiers, navigation clavier, infobulles multilingues et DMG signe pour Apple Silicon.

## Licence

MIT License.
