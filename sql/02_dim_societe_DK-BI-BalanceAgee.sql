/* ============================================================================
   View         : dbo.v_DimSociete
   Layer        : Dimension (référentiel sociétés)
   Grain        : 1 ligne par société accessible via le périmètre de partage
   Owner        : Debassane K.
   Updated      : 2026-05-02
   ----------------------------------------------------------------------------
   Purpose
     Liste distincte des sociétés visibles dans le périmètre de partage
     autorisé. Sert de filtre maître côté Power BI pour la sélection multi-
     sociétés et les calculs de cumul.

   Dependencies
     Source tables (Sage 1000) :
       TDBFPERIMETREPARTAGE   pp   périmètre autorisé (point d'entrée)
       TDBFPERIMETREDOMAINE   pd   liaison périmètre autorisé -> partagé
       TDBFPERIMETREPARTAGE   pp2  périmètre cible (libellé société)
       TPARAMETRESOCIETE      ps   identifiant technique (oidShare)
       TTIERS                 tt   code société (LEFT JOIN)

   Consumers
     - Power BI : table de dimension Société, jointe à v_FactBalanceAgee.ID_Societe.

   Conventions
     - LEFT JOIN sur TTIERS pour conserver les sociétés sans code tiers
       (Code_Societe NULL dans ce cas).
     - DISTINCT pour éliminer les doublons issus de la multiplicité des
       domaines pour un même périmètre cible.

   Change log
     2026-04-29  v1.0  Création initiale
     2026-05-02  v2.0  Renommage : view_Societes_Perimetre -> v_DimSociete
                       Header normalisé, formatage homogène
============================================================================ */
CREATE OR ALTER VIEW [dbo].[v_DimSociete]
AS
SELECT DISTINCT
    -- ------------------------------------------------------------------------
    -- Clé primaire
    -- ------------------------------------------------------------------------
    ps.oidShare                                       AS ID_Societe,

    -- ------------------------------------------------------------------------
    -- Attributs société
    -- ------------------------------------------------------------------------
    tt.Caption                                        AS Code_Societe,
    pp2.Caption                                       AS Societe_Libelle

FROM            TDBFPERIMETREPARTAGE   pp
INNER JOIN      TDBFPERIMETREDOMAINE   pd  ON pd.oidPerimetreAutorise = pp.oid
INNER JOIN      TDBFPERIMETREPARTAGE   pp2 ON pp2.oid                 = pd.oidPerimetrePartage
INNER JOIN      TPARAMETRESOCIETE      ps  ON ps.oidShare             = pp2.oid
LEFT  JOIN      TTIERS                 tt  ON tt.oidPerimetreSociete  = ps.oidShare;
GO
