/* ============================================================================
   View         : dbo.v_DimTiers
   Layer        : Dimension (référentiel tiers)
   Grain        : 1 ligne par couple Tiers x Rôle (un tiers peut porter
                  plusieurs rôles : Client + Fournisseur, etc.)
   Owner        : Debassane K.
   Updated      : 2026-05-02
   ----------------------------------------------------------------------------
   Purpose
     Référentiel des tiers actifs avec leur rôle et leur classification
     métier (Client / Fournisseur / Salarié / Divers tiers). Sert de
     dimension principale d'analyse côté Power BI.

   Dependencies
     Source tables (Sage 1000) :
       TTIERS       t    référentiel tiers
       TROLETIERS   rt   rôles portés par chaque tiers (1-N)

   Consumers
     - Power BI : dimension principale, jointe à v_FactBalanceAgee.ID_Tiers.

   Conventions
     - Filtre t.inactif = 0 : seuls les tiers actifs sont remontés.
       Retirer pour inclure l'historique complet.
     - Tiers_Type : classification dérivée de la première lettre du libellé
       de rôle (C = Client, F = Fournisseur, S = Salarié). Si la convention
       de nommage des rôles évolue dans Sage, cette logique est à réviser.
     - ID_Tiers : clé composite oidShare + code, alignée avec
       v_FactBalanceAgee.ID_Tiers pour les jointures cross-sociétés.

   Change log
     2026-04-29  v1.0  Création initiale
     2026-05-02  v2.0  Renommage : view_Tiers -> v_DimTiers
                       Header normalisé, formatage homogène
============================================================================ */
CREATE OR ALTER VIEW [dbo].[v_DimTiers]
AS
SELECT DISTINCT
    -- ------------------------------------------------------------------------
    -- Clé primaire
    -- ------------------------------------------------------------------------
    CONCAT(t.oidShare,'|', rt.oid, '|', rt.oidTiers)   AS ID_Tiers,

    -- ------------------------------------------------------------------------
    -- Attributs tiers
    -- ------------------------------------------------------------------------
    t.code                                            AS Tiers_Code,
    t.Caption                                         AS Tiers_Libelle,
    t.raisonSociale                                   AS Raison_Sociale,

    -- ------------------------------------------------------------------------
    -- Rôle et classification métier
    -- ------------------------------------------------------------------------
    rt.Caption                                        AS RoleTiers_Libelle,

    CASE LEFT(rt.Caption, 1)
        WHEN 'C' THEN 'Client'
        WHEN 'F' THEN 'Fournisseur'
        WHEN 'S' THEN 'Salarie'
        ELSE          'Divers tiers'
    END                                               AS Tiers_Type

FROM            TTIERS       t
INNER JOIN      TROLETIERS   rt ON rt.oidTiers = t.oid

WHERE   t.inactif = 0;
GO
