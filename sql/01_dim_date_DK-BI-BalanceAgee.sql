/* ============================================================================
   View         : dbo.v_DimDate
   Layer        : Dimension (calendar)
   Grain        : 1 ligne par jour
   Owner        : Debassane K.
   Updated      : 2026-05-02
   ----------------------------------------------------------------------------
   Purpose
     Table de dimension calendrier contiguë (sans trous ni doublons) destinée
     à servir de Date Table dans le modèle Power BI. Désactive de fait les
     LocalDateTable cachées générées automatiquement par Power BI.

   Dependencies
     - sys.all_objects (catalogue système, utilisé pour le tally pattern)

   Consumers
     - Power BI : marquée comme Date Table, branchée à v_FactBalanceAgee sur
       les colonnes DateEcheance (relation active), DatePiece et DateLettrage
       (relations inactives, activées via USERELATIONSHIP).

   Conventions
     - Plage     : du 2020-01-01 au 31/12 de l'année (N+1) recalculée à chaque
                   rafraîchissement.
     - Locale    : libellés mois et jours en français (fr-FR).
     - Tri Mois  : YYYYMM, à utiliser comme Sort By Column de [Mois] et
                   [Annee-Mois] (sinon ordre alphabétique sur les libellés).

   Change log
     2026-05-01  v1.0  Création initiale (CTE récursive — KO car
                       MAXRECURSION interdit dans une vue)
     2026-05-01  v1.1  Refonte avec tally pattern (sys.all_objects)
     2026-05-01  v1.2  Ajout des clés [Tri Mois] et [Tri Trimestre]
     2026-05-02  v2.0  Header normalisé, formatage homogène avec les autres vues
============================================================================ */
CREATE OR ALTER VIEW [dbo].[v_DimDate]
AS
WITH bornes AS
(
    SELECT
        CAST('2020-01-01' AS DATE)                                   AS DateMin,
        CAST(DATEFROMPARTS(YEAR(GETDATE()) + 1, 12, 31) AS DATE)     AS DateMax
),
tally AS
(
    -- Tally pattern : produit un flux d'entiers 0..N sans récursion.
    -- sys.all_objects en CROSS JOIN fournit largement assez de lignes pour
    -- générer plusieurs décennies de dates contiguës.
    SELECT TOP (DATEDIFF(DAY, (SELECT DateMin FROM bornes),
                              (SELECT DateMax FROM bornes)) + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM   sys.all_objects a
    CROSS  JOIN sys.all_objects b
),
calendrier AS
(
    SELECT DATEADD(DAY, n, (SELECT DateMin FROM bornes)) AS [Date]
    FROM   tally
)
SELECT
    -- ------------------------------------------------------------------------
    -- Clé primaire
    -- ------------------------------------------------------------------------
    c.[Date]                                                          AS [Date],

    -- ------------------------------------------------------------------------
    -- Hiérarchie temporelle
    -- ------------------------------------------------------------------------
    YEAR(c.[Date])                                                    AS [Annee],
    DATEPART(QUARTER, c.[Date])                                       AS [Trimestre Num],
    'T' + CAST(DATEPART(QUARTER, c.[Date]) AS VARCHAR(1))             AS [Trimestre],
    MONTH(c.[Date])                                                   AS [Mois Num],
    FORMAT(c.[Date], 'MMMM', 'fr-FR')                                 AS [Mois],
    LEFT(FORMAT(c.[Date], 'MMM',  'fr-FR'), 3)                        AS [Mois Court],
    FORMAT(c.[Date], 'yyyy-MM')                                       AS [Annee-Mois],
    DAY(c.[Date])                                                     AS [Jour],

    -- ------------------------------------------------------------------------
    -- Clés de tri chronologiques (Sort By Column dans Power BI)
    -- ------------------------------------------------------------------------
    YEAR(c.[Date]) * 100 + MONTH(c.[Date])                            AS [Tri Mois],
    YEAR(c.[Date]) *  10 + DATEPART(QUARTER, c.[Date])                AS [Tri Trimestre],

    -- ------------------------------------------------------------------------
    -- Axes secondaires
    -- ------------------------------------------------------------------------
    DATEPART(WEEK, c.[Date])                                          AS [Semaine],
    DATENAME(WEEKDAY, c.[Date])                                       AS [Jour Semaine],
    ((DATEPART(WEEKDAY, c.[Date]) + @@DATEFIRST - 2) % 7) + 1         AS [Jour Semaine Num],
    EOMONTH(c.[Date])                                                 AS [Fin de Mois],

    -- ------------------------------------------------------------------------
    -- Indicateurs booléens
    -- ------------------------------------------------------------------------
    CASE WHEN c.[Date] = EOMONTH(c.[Date])           THEN 1 ELSE 0 END AS [EstFinDeMois],
    CASE WHEN DATEPART(WEEKDAY, c.[Date]) IN (1, 7)  THEN 1 ELSE 0 END AS [EstWeekend]

FROM calendrier c;
GO
