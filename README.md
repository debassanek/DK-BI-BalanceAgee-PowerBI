
**Cas pratique end-to-end : Sage 1000 → SQL Server → Power BI**


Un projet personnel construit autour d'un cas réel : la balance âgée client à partir de données Sage 1000. C'est un sujet qui semble simple sur le papier (qui doit combien, depuis quand) mais qui devient vite illisible dès qu'on l'attaque dans les écrans natifs d'un ERP. L'idée du projet était de partir d'un export brut, de tout reconstruire proprement côté SQL, et d'arriver à un rapport sur lequel une équipe finance pourrait réellement s'appuyer pour piloter son recouvrement.

Les données utilisées sont réelles (données historiques) mais entièrement anonymisées : codes tiers, raisons sociales et montants ont été retravaillés pour rester représentatifs sans exposer quoi que ce soit de sensible.

## Le sujet que j'essayais de résoudre

Quand on est dans une équipe finance, la question revient en boucle : qui doit-on relancer en priorité cette semaine ? On a en général une balance auxiliaire qui sort, une liste interminable, et chacun fait son tri à la main dans Excel. On finit par perdre du temps sur les mauvais clients et on rate les vrais signaux faibles.

Je voulais un outil qui réponde à trois choses :

- voir d'un coup où se concentre le risque,
- pouvoir descendre jusqu'à la facture précise sans changer d'écran,
- comparer la situation à différentes dates pour suivre une tendance plutôt qu'une photo.

## Aperçu du rapport

Le rapport est structuré en quatre pages, chacune répond à un usage précis.

### La synthèse

![Vue synthèse- KPI clés et répartition par tranche de retard](https://raw.githubusercontent.com/debassanek/DK-BI-BalanceAgee-PowerBI/main/img/01_Vue%20Synth%C3%A9tique_BA_DK-BI-BalanceAgee.png)

*Vue synthèse : KPI clés et répartition par tranche de retard.*

C'est la page d'entrée. Cinq KPI en haut (solde des créances, encours à risque au-delà de 60 jours, % de risque crédit moyen et sur le segment +90j, niveau de risque sur 5), et en dessous la répartition du solde par tranche de retard. À cette date de référence (juin 2022 sur la capture), on voit immédiatement que le risque se concentre sur les tranches au-delà de 60 jours, ce qui change la lecture par rapport au seul total brut de 14,7 M€. La présence d'un solde négatif sur la tranche 31-60 j signale aussi des avoirs ou des trop-perçus à investiguer.

### Le détail selon la tranche de retard

![Matrice client × tranche de retard et Pareto des 10 plus gros encours](https://raw.githubusercontent.com/debassanek/DK-BI-BalanceAgee-PowerBI/main/img/02_D%C3%A9tail_BA_DK-BI-BalanceAgee.png)

*Matrice client × tranche de retard et Pareto des 10 plus gros encours.*

Une matrice client × tranche de retard avec un dégradé de couleur, doublée d'un Pareto sur les 10 plus gros encours. C'est la page que j'ouvrirais en premier en tant que credit manager : elle dit en deux secondes par où commencer la relance. Les valeurs négatives ressortent, ce qui force à les traiter à part — un avoir non rapproché peut camoufler un vrai retard sous un total apparemment équilibré.

### L'évolution du solde dans le temps

![Variation Mois sur Mois et part cumulée des créances par tranche](https://raw.githubusercontent.com/debassanek/DK-BI-BalanceAgee-PowerBI/main/img/03_Evolution%20temporelle_BA_DK-BI-BalanceAgee.png)

*Variation Mois sur Mois et part cumulée des créances par tranche.*

La même information, mais en mouvement : variation mois sur mois, répartition mensuelle empilée par tranche, et part cumulée des créances par tranche. Utile pour voir si une dérive s'installe ou si une action de relance a réellement produit un effet.

### La fiche client

![Drill-through : zoom sur un client (ici XIDEV0009)](https://raw.githubusercontent.com/debassanek/DK-BI-BalanceAgee-PowerBI/main/img/04_Fiche%20Clien%20%28Extraire%29_BA_DK-BI-BalanceAgee.png)

*Drill-through : zoom sur un client (ici XIDEV0009).*

Accessible en drill-through depuis n'importe quelle page : on clique-droit sur un client, on atterrit sur sa fiche détaillée avec son solde, son nombre de factures en cours, son retard maximum, son DPM réel et la liste de toutes ses factures ouvertes. C'est la page qui évite les allers-retours entre Power BI et l'ERP.

## Comment c'est construit

![Architecture technique end-to-end : Sage 1000 → SQL Server → Power BI](https://raw.githubusercontent.com/debassanek/DK-BI-BalanceAgee-PowerBI/main/img/05_Architecture_BA_DK-BI-BalanceAgee.png)

*Architecture technique end-to-end : Sage 1000 → SQL Server → Power BI.*

Le schéma ci-dessus reprend le flux de bout en bout. On part des tables natives de Sage 1000 dans la base source, on construit une couche de vues SQL qui matérialisent la logique métier (calcul du restant dû, rattachement aux dimensions, table de dates contiguë), Power BI s'appuie ensuite sur ce socle propre pour exposer un modèle en étoile et une vingtaine de mesures DAX, restituées dans un rapport quatre pages destiné aux équipes finance. Les couches transverses — anonymisation, paramétrage de la date de référence, documentation et industrialisation du modèle — accompagnent chaque étape.

### Côté SQL

Cinq vues, toutes préfixées `v_` et schéma-qualifiées dans `dbo`, suivent une convention dim/fact explicite :

- `v_FactBalanceAgee`- la table de faits, au grain « 1 ligne par échéance ». Elle calcule le restant dû signé (positif pour une créance, négatif pour un trop-perçu), les jours de retard et la tranche d'ancienneté par rapport à une date de référence dynamique.
- `v_DimDate`- table de dates contiguë générée via tally pattern (sans `MAXRECURSION`, donc déployable en vue), qui sert de Date Table marquée dans Power BI.
- `v_DimTiers`, `v_DimTiersRole`, `v_DimSociete`- référentiels tiers, rôle et société, alignés par clé composite `oidShare | oid | oidTiers`.

La date de référence est portée par une table de paramétrage `dbo.PARAMETRE_DATE` jointe en `CROSS JOIN` à la fact
- changer cette ligne suffit à rejouer toute la balance à n'importe quel point dans le passé, depuis Power BI ou n'importe quel autre client SQL.

### Côté modèle

Schéma en étoile classique : une table de faits, quatre dimensions. `v_DimDate` est marquée comme Date Table, avec la relation active sur la date d'échéance et deux relations inactives sur la date de pièce et la date de lettrage, activables au cas par cas via `USERELATIONSHIP`. Ça évite les ambiguïtés et permet de répondre à plusieurs questions temporelles avec le même modèle.

### Côté DAX

Une dizaine de mesures de base (solde, échu, non échu, retard moyen pondéré, niveau de risque) et quelques mesures de variation (M/M, % cumulé). Après une première version qui traînait des vieilles mesures de test, j'ai fait une passe de nettoyage : 19 mesures finales rangées en cinq dossiers, format strings homogènes, code mort supprimé. Le pack de cleanup (audit Excel + script Tabular Editor + changelog) est versionné dans le repo.

## Choix techniques que j'assume

Quelques décisions valent la peine d'être expliquées :

- **Date de référence portée par une table SQL** plutôt que par un paramètre Power BI. Ça permet de rejouer la balance depuis n'importe quel client SQL (Excel, autre rapport, batch comptable) avec le même résultat que dans le rapport. C'est plus robuste qu'un paramètre M qui ne vit que dans le `.pbix`.
- **Logique métier centralisée dans des vues SQL** plutôt qu'éclatée entre Power Query et DAX. Le calcul du restant dû, du retard et de la tranche se fait une seule fois, côté serveur. Power BI consomme du prêt-à-l'emploi, ce qui simplifie le modèle et garde la même définition de vérité quel que soit l'outil de restitution.
- **Restant dû signé** (positif pour une créance, négatif pour un trop-perçu). Ça fait apparaître les avoirs non rapprochés dans la balance plutôt que de les masquer dans des totaux nets. Pour une équipe recouvrement, c'est un signal opérationnel, pas une nuisance.
- **Drill-through plutôt qu'une page « détail » exhaustive**. La fiche client n'apparaît que quand on en a besoin, ce qui garde les pages de synthèse lisibles et rapides à charger.
- **Une seule date active sur la fact**. J'ai préféré la simplicité d'une relation principale claire, quitte à utiliser `USERELATIONSHIP` pour les rares mesures qui regardent la date de pièce ou de lettrage.
- **Convention de nommage `v_<Dim|Fact><Domaine>`** sur l'ensemble des vues, schéma `dbo` explicite, headers normalisés (Purpose, Grain, Dependencies, Consumers, Conventions, Change log). Le but : qu'un autre analyste puisse reprendre le projet sans se poser de questions sur la grain ou les dépendances de chaque vue.

## Stack

SQL Server (T-SQL, vues) pour la préparation. Power BI Desktop avec DAX pour la modélisation, les mesures et la visualisation. Tabular Editor pour le nettoyage du modèle. Git pour le versioning.

## Ce que je voulais montrer avec ce projet

Plus que le rapport en lui-même, ce projet m'a servi à donner un aperçu de la réalité sur le terrain : à savoir mettre bout à bout la chaîne complète, récupérer des données dans un ERP, en faire quelque chose de propre côté entrepôt, modéliser pour l'analyse, et arriver à un livrable utilisable par un métier. C'est aussi l'occasion de montrer que je sais travailler sur de la donnée réelle avec ses contraintes (anonymisation, lettrage, dates multiples, montants signés) plutôt que sur un dataset Kaggle déjà mâché.

Côté métier, ça illustre que je comprends de quoi parle un credit manager : la différence entre échu et non échu, pourquoi la tranche 61-90 fait peur, à quoi sert un DPM réel, ce que masque un total net positif quand un avoir traîne.

## Code source et ressources

| Ressource | Fichier |
|---|---|
| Fact v_FactBalanceAgee|[`05_fact_balance_agee.sql`](https://github.com/debassanek/DK-BI-BalanceAgee-PowerBI/blob/main/sql/05_fact_balance_agee_DK-BI-BalanceAgee.sql) |
| Dim v_DimDate | [`01_dim_date.sql`](https://github.com/debassanek/DK-BI-BalanceAgee-PowerBI/blob/main/sql/01_dim_date_DK-BI-BalanceAgee.sql) |
| Dim v_DimSociete | [`02_dim_societe.sql`](https://github.com/debassanek/DK-BI-BalanceAgee-PowerBI/blob/main/sql/02_dim_societe_DK-BI-BalanceAgee.sql) |
| Dim v_DimTiers | [`03_dim_tiers.sql`](https://github.com/debassanek/DK-BI-BalanceAgee-PowerBI/blob/main/sql/03_dim_tiers_DK-BI-BalanceAgee.sql) |
| Dim v_DimTiersRole | [`04_dim_tiers_role.sql`](https://github.com/debassanek/DK-BI-BalanceAgee-PowerBI/blob/main/sql/04_dim_tiers_role_DK-BI-BalanceAgee.sql) |
| Rapport Power BI complet | [`DK-BI-BalanceAgee_Report.pbix`](https://github.com/debassanek/DK-BI-BalanceAgee-PowerBI/blob/main/Ressources/DK-BI-BalanceAgee_Report.pbix)|

## Pistes d'évolution

Si je devais reprendre le projet, je regarderais : un passage en DirectQuery pour rafraîchir en temps réel sur le périmètre récent, un scoring du risque d'impayé un peu plus fin (un modèle simple suffirait, pas besoin de ML), des alertes Power Automate sur dépassement de seuil, et la mise en place d'un Row-Level Security par société pour pouvoir partager le rapport à plusieurs entités sans tout cloisonner manuellement.

---

**Debassane K.** - Data & BI - [debassanek@gmail.com](mailto:debassanek@gmail.com)
