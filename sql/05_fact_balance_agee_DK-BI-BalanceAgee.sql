
/* ============================================================================
   View         : dbo.v_FactBalanceAgee
   Layer        : Fact (analytical)
   Grain        : 1 ligne par échéance (TECHEANCE) à la date de référence
                  portée par dbo.PARAMETRE_DATE.
   Owner        : Debassane K.
   Updated      : 2026-05-02
   ----------------------------------------------------------------------------
   Purpose
     Construit la balance âgée des tiers en exposant pour chaque échéance :
       - le restant dû signé (positif = créance, négatif = créditeur),
       - les jours de retard et la tranche d'ancienneté,
       - le statut de lettrage,
       - les ventilations Débit/Crédit en montant TTC.

   Dependencies
     Source tables (Sage 1000) :
       TECHEANCE             ech   table pilote (grain)
       TECRITURE             e     écriture comptable parente
       TPIECE                tp    pièce comptable
       TJOURNAL              j     journal comptable
       TROLETIERS            rt    rôle du tiers
       TTIERS                t     identité du tiers
       TLETTRAGE             let   lettrage de l'échéance
       TLETTRAGEECRITURE     lt    libellé du lettrage
     Parameter table :
       dbo.PARAMETRE_DATE    p     1 ligne, 1 colonne DateReference

   Consumers
     - Power BI : table de faits centrale du modèle Balance Âgée.
     - Reporting Excel : extractions ad hoc à date.

   Conventions
     - sens                : 0 = Débit, 1 = Crédit (norme Sage 1000).
     - Montant_Restant_Du  : signé (Débit > 0, Crédit < 0).
     - Tranche_Retard      : Non échu, 1-30 j, 31-60 j, 61-90 j, +90 j.
     - Date de référence   : si PARAMETRE_DATE contient plusieurs lignes,
                             le CROSS JOIN multiplie le résultat. La table
                             doit donc contenir EXACTEMENT 1 ligne.

   Change log
     2026-04-26  v1.0  Création initiale
     2026-04-29  v2.0  Refonte structure
     2026-05-02  v3.0  Suppression du GROUP BY redondant (équivalent à
                       SELECT DISTINCT, sans agrégat).
                       Suppression du dead code (auto-jointure commentée).
                       Logique de tranche extraite en CTE pour éviter la
                       duplication entre Tranche_Retard et Ordre_Tranche.
                       Formule cryptique du restant dû remplacée par un
                       CASE explicite. Header normalisé.
============================================================================ */
CREATE OR ALTER VIEW [dbo].[v_FactBalanceAgee]
AS
WITH base AS
(
    SELECT
        -- ------------------------------------------------------------------
        -- Identifiants techniques
        -- ------------------------------------------------------------------
        e.numero                                          AS Numero_Ecriture,
        e.reference                                       AS Reference,
        e.oidShare                                        AS ID_Societe,
        CONCAT(rt.oidShare, '|', rt.oid,'|',rt.oidTiers)  AS ID_Tiers,
        CAST(ech.dateEcheance AS DATE)                    AS ID_Date,

        -- ------------------------------------------------------------------
        -- Pièce / écriture
        -- ------------------------------------------------------------------
        tp.numero                                         AS Numero_Piece,
        tp.pDate                                          AS Piece_Date,
        tp.numero_CounterName                             AS Piece_Nature,
        j.code                                            AS Journal_Code,
        e.montant                                         AS Ecriture_Montant,
        e.sens                                            AS Sens_Ecriture,

        -- ------------------------------------------------------------------
        -- Échéance et ancienneté
        -- ------------------------------------------------------------------
        ech.dateEcheance                                  AS Echeance_Date,
        p.DateReference                                   AS Date_Reference,
        let.dateLettrage                                  AS Date_Lettrage,
        DATEDIFF(DAY, ech.dateEcheance, p.DateReference)  AS Jours_Retard,

        -- ------------------------------------------------------------------
        -- Lettrage
        -- ------------------------------------------------------------------
        lt.Caption                                        AS Ecriture_Lettrage,
        ech.oidLettrage                                   AS Lettrage_Oid,
        let.total                                         AS Lettrage_Total,

        -- ------------------------------------------------------------------
        -- Montants
        -- ------------------------------------------------------------------
        ech.sens                                          AS Echeance_Sens,
        ech.montant_TCValue                               AS Montant_TTC

    FROM            TECHEANCE          ech
    CROSS JOIN      dbo.PARAMETRE_DATE p
    LEFT  JOIN      TECRITURE          e   ON e.oidEcheance         = ech.oid
    INNER JOIN      TROLETIERS         rt  ON rt.oid                = e.oidroleTiers
    INNER JOIN      TTIERS             t   ON t.oid                 = rt.oidTiers
    LEFT  JOIN      TPIECE             tp  ON tp.oid                = e.oidpiece
    LEFT  JOIN      TLETTRAGEECRITURE  lt  ON lt.oid                = e.oidlettrageEcriture
    LEFT  JOIN      TLETTRAGE          let ON let.oid               = ech.oidLettrage
    INNER JOIN      TJOURNAL           j   ON j.oid                 = tp.oidjournal
)
SELECT DISTINCT
    -- ------------------------------------------------------------------------
    -- Identifiants
    -- ------------------------------------------------------------------------
    Numero_Ecriture,
    Reference,
    ID_Societe,
    ID_Tiers,
    ID_Date,

    -- ------------------------------------------------------------------------
    -- Pièce / écriture
    -- ------------------------------------------------------------------------
    Numero_Piece,
    Piece_Date,
    Piece_Nature,
    Journal_Code,
    Ecriture_Montant,
    Sens_Ecriture,

    -- ------------------------------------------------------------------------
    -- Échéance, ancienneté, tranche
    -- ------------------------------------------------------------------------
    Echeance_Date,
    Date_Reference,
    Date_Lettrage,
    Jours_Retard,

    CASE
        WHEN Jours_Retard <=  0                       THEN '0 - Non echu'
        WHEN Jours_Retard BETWEEN  1 AND  30          THEN '1 a 30 j'
        WHEN Jours_Retard BETWEEN 31 AND  60          THEN '31 a 60 j'
        WHEN Jours_Retard BETWEEN 61 AND  90          THEN '61 a 90 j'
        ELSE                                               '+90 j'
    END                                               AS Tranche_Retard,

    CASE
        WHEN Jours_Retard <=  0                       THEN 1
        WHEN Jours_Retard BETWEEN  1 AND  30          THEN 2
        WHEN Jours_Retard BETWEEN 31 AND  60          THEN 3
        WHEN Jours_Retard BETWEEN 61 AND  90          THEN 4
        ELSE                                               5
    END                                               AS Ordre_Tranche,

    -- ------------------------------------------------------------------------
    -- Lettrage
    -- ------------------------------------------------------------------------
    Ecriture_Lettrage,

    CASE
        WHEN Lettrage_Oid   IS NULL                   THEN 'Non lettree'
        WHEN Lettrage_Total = 0                       THEN 'Lettrage partiel'
        WHEN Lettrage_Total = 1                       THEN 'Lettrage total'
        ELSE                                               'Lettrage inconnu'
    END                                               AS Lettrage_Statut,

    -- ------------------------------------------------------------------------
    -- Montants signés
    -- ------------------------------------------------------------------------
    CASE Echeance_Sens
        WHEN 0 THEN  Montant_TTC      -- Débit  : créance sur le tiers
        WHEN 1 THEN -Montant_TTC      -- Crédit : avance / trop-perçu
    END                                               AS Montant_Restant_Du,

    CASE WHEN Echeance_Sens = 0 THEN Montant_TTC ELSE 0 END AS Debit_Echeance_TTC,
    CASE WHEN Echeance_Sens = 1 THEN Montant_TTC ELSE 0 END AS Credit_Echeance_TTC

FROM base;
GO
