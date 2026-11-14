# Redmine Form Sections

Redmine Form Sections est un plugin permettant de personnaliser
la disposition des champs personnalisés (Custom Fields) dans
les formulaires Redmine.

Il permet de regrouper ces champs dans des sections nommées,
organisées sur une ou deux colonnes.

**Le plugin agit exclusivement sur les champs personnalisés.**
Les champs natifs de Redmine (Sujet, Description, Statut,
Priorité, Assigné à, etc.) conservent leur disposition habituelle.

## Fonctionnalités

- Configuration des sections par tracker.
- Disposition sur une ou deux colonnes.
- Activation du plugin individuellement par projet.
- Configuration centralisée au format YAML.
- Validation de la configuration avant enregistrement.
- Détection des identifiants de champs déclarés plusieurs fois.
- Export de la configuration YAML.
- Interface disponible en français et en anglais.

Le plugin réorganise les champs existants dans le formulaire.
Il ne modifie ni leur définition ni leurs valeurs.

### Comportement

- Un tracker sans configuration conserve le formulaire Redmine natif.
- Une section sans champ présent dans le formulaire n'est pas affichée.
- Les champs non affectés à une section sont regroupés dans
  une section "Autres champs", lorsqu'ils sont présents.
- Les champs absents du formulaire ne sont pas ajoutés artificiellement.

## Compatibilité

Version du plugin : 0.1.0

Environnement de développement et de test :
- Redmine 7.0.3
- PostgreSQL 17

La compatibilité avec d'autres versions de Redmine
n'a pas encore été vérifiée.

## Installation

1. Copier le répertoire `redmine_form_sections` dans
   le répertoire `plugins` de Redmine.

2. Redémarrer Redmine.

3. Dans **Administration > Plugins**, vérifier que
   "Redmine Form Sections" apparaît dans la liste.

Aucune migration de base de données n'est nécessaire
pour cette version du plugin.

## Activation

Le plugin doit être activé sur chaque projet concerné.

1. Ouvrir le projet.
2. Accéder à **Configuration > Modules**.
3. Activer **Personnalisation des formulaires**.
4. Enregistrer.

Les projets sur lesquels le module est désactivé
conservent le comportement natif de Redmine.

## Configuration

Accéder à :

**Administration > Plugins > Redmine Form Sections > Configurer**

La disposition des champs personnalisés est définie au format YAML.

### Exemple de configuration

```yaml
trackers:
  1:
    - title: "Application"
      left: [1, 2]
      right: [5]

    - title: "Client"
      left: [3, 4]
      right: [6, 7]
```

Dans cet exemple :

- `trackers` contient les configurations des différents trackers.
- `1` est l'identifiant du tracker Redmine.
- `title` définit le titre de la section.
- `left` contient les identifiants des champs personnalisés
  à afficher dans la colonne de gauche.
- `right` contient les identifiants des champs personnalisés
  à afficher dans la colonne de droite.

**Les nombres indiqués dans `left` et `right` correspondent
aux identifiants des champs personnalisés Redmine (Custom Field IDs),
et non à leur position dans le formulaire.**

Plusieurs champs peuvent être placés dans une même colonne
en séparant leurs identifiants par des virgules.

Par exemple :

```yaml
left: [12, 15, 23]
```

Cette configuration place successivement les champs personnalisés
12, 15 et 23 dans la colonne de gauche.

**L'ordre des identifiants détermine l'ordre d'affichage des champs
dans la colonne.**

### Identifier un champ personnalisé

Dans Redmine :

1. Accéder à **Administration > Champs personnalisés**.
2. Sélectionner le champ personnalisé concerné.
3. Repérer son identifiant dans l'URL.

Exemple :

`https://redmine.exemple.fr/custom_fields/123/edit`

Dans cet exemple, l'identifiant du champ personnalisé est `123`.

### Organisation des colonnes

Si `right` est déclaré, la section utilise deux colonnes,
même si l'une des listes est vide.

Exemple :

```yaml
- title: "Application"
  left: [1, 2]
  right: []
```

La section utilise deux colonnes, mais seule celle de gauche
contient des champs.

Si seul `left` est déclaré, la section utilise une colonne
sur toute la largeur disponible.

Exemple :

```yaml
- title: "Application"
  left: [1, 2]
```

La colonne `left` est obligatoire.

Une section doit déclarer au moins un champ personnalisé.

Un même champ personnalisé ne peut pas être déclaré plusieurs
fois pour un même tracker.

### Organisation des colonnes

Si `right` est déclaré, la section utilise deux colonnes,
même si l'une des listes est vide.

Si seul `left` est déclaré, la section utilise une colonne
sur toute la largeur disponible.

La colonne `left` est obligatoire.

Une section doit déclarer au moins un champ.

Un même champ ne peut pas être déclaré plusieurs fois
pour un même tracker.

### Champs personnalisés en pleine largeur

Le plugin respecte l'option native de Redmine permettant d'afficher
un champ personnalisé sur toute la largeur du formulaire.

Lorsqu'un champ est configuré en pleine largeur dans Redmine :

- Il peut être déclaré indifféremment dans `left` ou `right` dans le YAML.
- Il est affiché sous les colonnes de la section correspondante,
  sur toute la largeur disponible.
- S'il n'est déclaré dans aucune section, il est placé à la fin
  de la section automatique « Autres champs ».
- Si une section contient uniquement des champs en pleine largeur,
  aucune structure de colonnes inutile n'est créée.

Le plugin conserve les contrôles HTML générés par Redmine,
y compris les éditeurs de texte avec formatage.

Cette personnalisation concerne exclusivement les champs personnalisés.
Les champs natifs de Redmine ne sont pas réorganisés.

## Export de la configuration

L'écran d'administration permet de télécharger
la configuration YAML.

L'export est réservé aux administrateurs Redmine.

## Tests

Le code source contient des tests unitaires et
des tests d'intégration.

Ils permettent notamment de vérifier :

- La validation des configurations YAML.
- La détection des configurations incorrectes.
- Le comportement de l'administration.
- L'export et ses restrictions d'accès.

Ces tests ne sont pas nécessaires au fonctionnement
normal du plugin.

## Limitations actuelles

- La configuration est commune à tous les projets
  utilisant un même tracker.
- Il n'existe pas encore d'éditeur visuel.
- La compatibilité avec les anciennes versions
  de Redmine reste à vérifier.
- La disposition des champs natifs de Redmine n'est 
  pas personnalisable.

## Auteur

Julien Maisonnas

## Licence

Copyright (C) 2026 Julien Maisonnas

Redmine Form Sections est distribué sous les termes de la
GNU General Public License, version 2 ou ultérieure
(GPL-2.0-or-later).

Voir le fichier [LICENSE](LICENSE) pour le texte intégral
de la licence.