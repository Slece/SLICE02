# SMC Trading Bot

Implémentations multi-plateformes du robot SMC demandé :

- `mql5/SMC_Synthetic_EA.mq5` — Expert Advisor MetaTrader 5
- `python/smc_mt5.py` — pont Python/MT5
- `tradingview/smc_strategy.pine` — indicateur/stratégie TradingView
- `dbot/smc_template.xml` — modèle à finaliser dans Deriv DBot

## Règle de sécurité

Aucune implémentation ne doit être utilisée en réel avant validation sur compte démo, données historiques et suivi forward. Les stratégies sont fournies avec 5 % de risque maximum par défaut uniquement pour correspondre aux réglages demandés ; ce niveau est agressif et peut être modifié à 0,5–1 %.

## Structure recommandée

- H1 : calcul du biais après CHoCH/BOS
- M15 : recherche OB/FVG
- Bougie M15 : engulfing ou rejet
- Entrée limitée ou marché
- SL derrière OB
- TP = 2,5 × le risque
- 10 trades maximum/jour
- Arrêt à +100 % ou -25 %

## Tests

Les détecteurs BOS/CHoCH/OB/FVG ne doivent jamais être remplacés par des comparaisons arbitraires dans une version réelle.
