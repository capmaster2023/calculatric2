# Calculatrice APK

Projet prêt pour GitHub Actions.

- Nom de l’app : Calculatrice
- Icône : calculatrice
- Écran récent : l’app revient à la calculatrice quand elle passe en arrière-plan via JS.
- Build : Actions > Build Android APK > Run workflow.


## Modification galerie
- La calculatrice reste dans `www/index.html`.
- Le calcul secret ouvre maintenant `www/galerie.html`.
- `www/galerie.html` vient du projet `coffre-app.zip`.

## Fix vidéos longues / codecs
Cette version ajoute un pont natif Android `NativeVideo` + ExoPlayer.

- Les vidéos ne sont plus lancées avec la balise HTML `<video>` quand l'app tourne dans Capacitor Android.
- La vidéo est copiée par morceaux depuis IndexedDB vers le cache Android, puis ouverte avec ExoPlayer.
- Ça corrige les vidéos longues et les codecs/conteneurs que la WebView Android ne sait pas lire, comme certains `.ts`, HEVC/H.265 ou AV1 selon le téléphone.
- Si l'app est ouverte dans un navigateur normal, elle garde le fallback `<video>`.

## Mise à jour demandée
- Quand l'application passe en arrière-plan (Accueil, applications récentes, changement d'app), Android recharge automatiquement l'écran Calculatrice.
- Les vidéos affichent maintenant une image preview prise vers le milieu de la vidéo avec le pont natif Android quand l'APK est compilé.

## Ajout navigateur privé
- Bouton Navigateur dans la galerie.
- Permet d’ouvrir un lien web et de télécharger un lien direct de vidéo/fichier dans le coffre de l’app.
- Le téléchargement passe par le stockage privé/cache de l’application, puis est importé dans la galerie avec preview vidéo.
- Les fichiers ne sont pas enregistrés dans Download/DCIM par cette fonction.
