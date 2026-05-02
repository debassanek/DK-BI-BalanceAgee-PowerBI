# DK-BI-BalanceAgee-PowerBI

# Dashboard Power BI — Balance Âgée Clients 
**Cas pratique end-to-end : Sage 1000 → SQL Server → Power BI** 

Construire un outil de pilotage du recouvrement à partir d'un export ERP brut, en passant par une couche SQL propre et un modèle Power BI étoile

. [Aperçu du rapport](#aperçu-du-rapport) 
· [Architecture](#architecture-technique) 
· [Vues SQL](#vues-sql) 
· [Choix techniques](#choix-techniques-que-jassume) 
· [Code source](#code-source-et-ressources)

En bref
Domaine	Finance — recouvrement client
Stack	SQL Server (T-SQL, vues) · Power BI Desktop · DAX · Tabular Editor · Git
Source	Sage 1000 (dbSage1000FRP) — données réelles anonymisées
Livrable	5 vues SQL + 1 modèle Power BI étoile (4 pages, 19 mesures DAX)
Période couverte	2022 (date de référence dynamique)
Volumétrie	~14,7 M€ d'encours sur le périmètre, ~2 200 échéances

Le problème
Quand on est dans une équipe finance, la question revient en boucle : qui doit-on relancer en priorité cette semaine ? On a en général une balance auxiliaire qui sort, une liste interminable, et chacun fait son tri à la main dans Excel. On finit par perdre du temps sur les mauvais clients et on rate les vrais signaux faibles.

Je voulais un outil qui réponde à trois choses : voir d'un coup où se concentre le risque, pouvoir descendre jusqu'à la facture précise sans changer d'écran, et comparer la situation à différentes dates pour suivre une tendance plutôt qu'une photo.

Aperçu du rapport
Page 1 — La synthèse

![Vue synthétique](01_Vue%20Synth%C3%A9tique_BA.png) 

Cinq KPI en haut (solde des créances, encours à risque au-delà de 60 jours, % de risque crédit moyen et sur le segment +90j, niveau de risque sur 5), et en dessous la répartition du solde par tranche de retard. À cette date de référence (juin 2022 sur la capture), le risque se concentre sur les tranches au-delà de 60 jours, ce qui change la lecture par rapport au seul total brut de 14,7 M€. La présence d'un solde négatif sur la tranche 31-60 j signale aussi des avoirs ou des trop-perçus à investiguer.
Page 2 — Le détail par tranche
Page 3 — L'évolution dans le temps
Page 4 — La fiche client (drill-through)
Architecture technique


Sources Sage 1000 → vues SQL nettoyées → modèle Power BI étoile + DAX → rapport finance


On part des tables natives de Sage 1000 dans la base dbSage1000FRP. Une couche de vues SQL matérialise la logique métier (calcul du restant dû signé, rattachement aux dimensions, table de dates contiguë). Power BI s'appuie ensuite sur ce socle propre pour exposer un modèle en étoile et une vingtaine de mesures DAX, restituées dans un rapport quatre pages destiné aux équipes finance. Les couches transverses — anonymisation, paramétrage de la date de référence, documentation et industrialisation du modèle — accompagnent chaque étape.

Vues SQL
Cinq vues, toutes préfixées v_ et schéma-qualifiées dans dbo. Convention v_<Dim|Fact><Domaine> pour rendre le rôle de chaque vue lisible au premier coup d'œil.

Vue	Couche	Grain	Fichier
v_FactBalanceAgee	Fact	1 ligne par échéance	05_fact_balance_agee.sql
v_DimDate	Dim	1 ligne par jour	01_dim_date.sql
v_DimSociete	Dim	1 ligne par société	02_dim_societe.sql
v_DimTiers	Dim	1 ligne par couple Tiers × Rôle	03_dim_tiers.sql
v_DimTiersRole	Dim étendue	1 ligne par rôle (fiche complète)	04_dim_tiers_role.sql

La date de référence est portée par une table de paramétrage dbo.PARAMETRE_DATE jointe en CROSS JOIN à la fact — changer cette ligne suffit à rejouer toute la balance à n'importe quel point dans le passé, depuis Power BI ou n'importe quel autre client SQL.

Chaque fichier suit un header normalisé : Purpose / Layer / Grain / Owner / Updated / Dependencies / Consumers / Conventions / Change log.

Modèle Power BI

Schéma en étoile classique : une fact, quatre dimensions. v_DimDate est marquée comme Date Table, avec la relation active sur la date d'échéance et deux relations inactives sur la date de pièce et la date de lettrage, activables au cas par cas via USERELATIONSHIP. Ça évite les ambiguïtés et permet de répondre à plusieurs questions temporelles avec le même modèle.

Côté DAX : une dizaine de mesures de base (solde, échu, non échu, retard moyen pondéré, niveau de risque) et quelques mesures de variation (M/M, % cumulé). Après une première version qui traînait des mesures de test, j'ai fait une passe de nettoyage : 19 mesures finales rangées en cinq dossiers, format strings homogènes, code mort supprimé. Le pack de cleanup (audit Excel + script Tabular Editor + changelog) est versionné dans le repo.

Choix techniques que j'assume
Date de référence portée par une table SQL plutôt que par un paramètre Power BI. On rejoue la balance depuis n'importe quel client SQL avec le même résultat que dans le rapport. Plus robuste qu'un paramètre M qui ne vit que dans le .pbix.

Logique métier centralisée dans des vues SQL plutôt qu'éclatée entre Power Query et DAX. Le calcul du restant dû, du retard et de la tranche se fait une seule fois, côté serveur. Power BI consomme du prêt-à-l'emploi.

Restant dû signé (positif = créance, négatif = trop-perçu). Les avoirs non rapprochés deviennent visibles plutôt que masqués dans des totaux nets. Pour une équipe recouvrement, c'est un signal opérationnel.

Drill-through plutôt qu'une page "détail" exhaustive. La fiche client n'apparaît qu'à la demande, ce qui garde les pages de synthèse rapides à charger.

Une seule date active sur la fact. Simplicité d'une relation principale claire, quitte à utiliser USERELATIONSHIP pour les rares mesures qui regardent la date de pièce ou de lettrage.

Convention v_<Dim|Fact><Domaine> sur l'ensemble des vues, schéma dbo explicite, headers normalisés. Un autre analyste peut reprendre le projet sans se poser de questions sur la grain ou les dépendances de chaque vue.

Code source et ressources

Ressource	Description	Lien

Vues SQL	5 vues T-SQL refactorées (1 fact + 4 dim)	Dossier Vues SQL
Rapport Power BI	Fichier .pbix complet (4 pages, modèle, mesures DAX)	FRP1000_Balance Agée Synthétique.pbix
Pack nettoyage DAX	Audit Excel + script Tabular Editor + changelog	02_Cleanup_Mesures_DAX
Schéma d'architecture	Visuel haute résolution du flux end-to-end	05_Architecture_BA.png
Document Word	Note de présentation imprimable	Dashboard Power BI_papier.docx
Captures du rapport	Aperçus des 4 pages	Racine du dossier
Ce que je voulais montrer

Plus que le rapport en lui-même, ce projet m'a servi à mettre bout à bout la chaîne complète : récupérer des données dans un ERP, en faire quelque chose de propre côté entrepôt, modéliser pour l'analyse, et arriver à un livrable utilisable par un métier. C'est aussi l'occasion de montrer que je sais travailler sur de la donnée réelle avec ses contraintes (anonymisation, lettrage, dates multiples, montants signés) plutôt que sur un dataset Kaggle déjà mâché.

Côté finance, ça illustre que je comprends de quoi parle un credit manager — la différence entre échu et non échu, pourquoi la tranche 61-90 fait peur, à quoi sert un DPM réel, ce que masque un total net positif quand un avoir traîne.

Pistes d'évolution
Si je devais reprendre le projet, je regarderais : un passage en DirectQuery pour rafraîchir en temps réel sur le périmètre récent, un scoring du risque d'impayé un peu plus fin (un modèle simple suffirait, pas besoin de ML), des alertes Power Automate sur dépassement de seuil, et la mise en place d'un Row-Level Security par société pour pouvoir partager le rapport à plusieurs entités sans tout cloisonner manuellement.

**Debassane K.** — *BI Engineer / Data Analyst* debassanek@gmail.com
