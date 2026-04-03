# comments and wish list

- Semble que c'est pas clair qu'on peux rouler le tool en standalone, en service system-wide ou just avec docker.
- Si utilisation de la methode docker,  donner un example the Dockerfile functionnel.
   - [GP] TODO: Checker pour le dernier blob uploader sur DockerHub, mettre ca a jour.
- Elle dis que c'est pas clair pourquoi il y a des DB SQLite locale (dans db/) et quand ces dernieres sont utilisées
   - [GP] c'est vrai que c'est pas clair. Par default, elles ne sont pas utilisées et ne sont pas requises, c'est LEGACY. Les 2 boutons sont encore presents a coté du searh box (local database). Quand on selectionnent on tombe dans une page avec des films, ou des jeux (ata de la DB. les titres son toujours bon, mais expert level car il fautfetcher lemagnetlink updater, et ce faut avoir les inderxeurs....Bah c'Est complique pour tout le monde je vais disabler ca mais je garder dans une branche RD perso)

