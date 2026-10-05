# 実装に反映した開発資料

既存作品を模倣するためではなく、プレイヤーに結果と判断材料を伝える設計を確認するために、開発者の一次資料を参照しました。以下の適用内容は本作向けの判断です。

- [Factorio Friday Facts #325](https://www.factorio.com/blog/post/fff-325): 対象別の被弾効果と爆発表現。本作では非致死の命中に短い局所反応を追加し、大群全体への点滅は避けます。
- [Factorio Friday Facts #280](https://www.factorio.com/blog/post/fff-280): 状態や無効理由、操作の結果を見える形へ。本作では工廠の停止理由、選択部隊の命令、襲撃方向を表示します。
- [They Are Billions 公式紹介](https://www.numantiangames.com/TheyAreBillions/): 停止中の指揮と、騒音による群れへの影響。本作では初回起動の増援を起動前に明示します。
- [Against the Storm Modifiers Update](https://eremitegames.com/modifiers-update/): 選択による効果を事前に理解できるUI。本作では装備仕様票に現在値と採用後の値を表示します。
- [Against the Storm Tutorials and Tips Update](https://eremitegames.com/tutorials-and-tips-update/): 複雑な仕組みを行動と結び付けて学ぶ導入。本作では初回作戦だけ、行動完了で進む短い案内を既存の目標欄に置きます。
- [Age of Empires II: DE 公式UIガイド](https://www.ageofempires.com/learn-to-play/controlling-your-empire-gathering-resources-xbox/)、[Age of Empires IV Update 9.1.109](https://www.ageofempires.com/news/age-of-empires-iv-update-9-1-109/): 資源備蓄と資源ごとの作業人数を一緒に読み取れるUI。本作では既存の食料・廃材・部品欄に「担当」を追加し、移動・搬入を含む現在の採取命令の人数を示します。収入量とは分け、建設・修理・次の予約・枯渇後の待機は除きます。経路や搬入先を待つ担当者は既存の「待機」にも含まれます。

機能を増やすより、回収・復旧・補給・戦闘の因果が読めることを優先しています。面白さと初見理解は、自動テストや他作品の資料だけでは保証できません。
