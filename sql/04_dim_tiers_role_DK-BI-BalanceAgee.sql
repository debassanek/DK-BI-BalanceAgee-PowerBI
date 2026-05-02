
/* ============================================================================
   View         : dbo.v_DimTiersRole
   Layer        : Dimension étendue (fiche rôle tiers)
   Grain        : 1 ligne par rôle tiers (TROLETIERS), enrichi de la fiche
                  tiers, du site privilégié et de l'adresse postale.
   Owner        : Debassane K.
   Updated      : 2026-05-02
   ----------------------------------------------------------------------------
   Purpose
     Vue détaillée des rôles tiers : identité, capital, effectif, mode de
     règlement, site privilégié, SIRET, adresse, contact. Sert d'extension
     de v_DimTiers pour les pages drill-through (Fiche client) et les
     analyses qualifiées.

   Dependencies
     Source tables (Sage 1000) :
       TROLETIERS   rt   table pilote
       TTIERS       tt   identité tiers
       TSITE        s    site privilégié du rôle
       TADRESSE     ad   adresse du site

   Consumers
     - Power BI : drill-through Fiche Client, étiquettes détaillées.

   Conventions
     - LEFT JOIN sur TTIERS : un rôle peut techniquement exister sans tiers
       lié (cas marginaux).
     - Aucun filtre sur tt.inactif : la vue retourne aussi les rôles
       d'identités archivées. Ajouter WHERE tt.inactif = 0 si seuls les
       tiers actifs sont souhaités.
     - Tiers_Type : logique identique à v_DimTiers et v_FactBalanceAgee
       (à maintenir synchronisée).

   Change log
     2026-04-29  v1.0  Création initiale
     2026-05-02  v2.0  Renommage : view_Tiers (collision !) -> v_DimTiersRole
                       Suppression des jointures inactives sur
                       TPERIMETREGROUPETIERS, TPERIMETREGROUPE et TPAYS
                       (colonnes non exposées, risque de doublons silencieux).
                       Correction des typos d'alias (Province, Adresse,
                       Tiers_Commentaires). Header normalisé.
============================================================================ */
CREATE OR ALTER VIEW [dbo].[v_DimTiersRole]
AS
SELECT
    -- ------------------------------------------------------------------------
    -- Clé primaire
    -- ------------------------------------------------------------------------
    CONCAT(rt.oidShare, '|', rt.oid)                  AS ID_RoleTiers,

    -- ------------------------------------------------------------------------
    -- Rôle et classification métier
    -- ------------------------------------------------------------------------
    rt.Caption                                        AS RoleTiers_Libelle,

    CASE LEFT(rt.Caption, 1)
        WHEN 'C' THEN 'Client'
        WHEN 'F' THEN 'Fournisseur'
        WHEN 'S' THEN 'Salarie'
        ELSE          'Divers tiers'
    END                                               AS Tiers_Type,

    -- ------------------------------------------------------------------------
    -- Identité tiers
    -- ------------------------------------------------------------------------
    tt.code                                           AS Tiers_Code,
    tt.Caption                                        AS Tiers_Libelle,
    tt.capital                                        AS Capital_Tiers,
    tt.commentaire                                    AS Tiers_Commentaires,
    tt.effectif                                       AS Tiers_Effectif,
    tt.modeReglement                                  AS Tiers_ModeReglement,

    -- ------------------------------------------------------------------------
    -- Site privilégié
    -- ------------------------------------------------------------------------
    s.code                                            AS Site_Code,
    s.Caption                                         AS Site_Nom,
    s.codeSIRET                                       AS SIRET,

    -- ------------------------------------------------------------------------
    -- Coordonnées
    -- ------------------------------------------------------------------------
    ad.Caption                                        AS Adresse,
    ad.codePostal                                     AS Code_Postal,
    ad.cedex                                          AS Cedex,
    ad.complementAdresse                              AS Complement_Adresse,
    ad.etatProvince                                   AS Province,
    ad.eMail                                          AS Email,
    ad.telephone1                                     AS Telephone

FROM            TROLETIERS   rt
LEFT  JOIN      TTIERS       tt ON tt.oid = rt.oidTiers
LEFT  JOIN      TSITE        s  ON s.oid  = rt.oidsitePrivilegie
LEFT  JOIN      TADRESSE     ad ON ad.oid = s.oidAdresse;
GO
