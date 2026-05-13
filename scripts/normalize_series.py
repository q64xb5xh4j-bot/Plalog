
import csv
import shutil

input_file = '/Users/hiro/Desktop/アプリ開発/Pralog/Plalog/gunpla_catalog.csv'
output_file = '/Users/hiro/Desktop/アプリ開発/Pralog/Plalog/gunpla_catalog_normalized.csv'

# MAPPING DEFINITIONS
series_map = [
    # Top Priority: Specific Series
    ("復讐のレクイエム", "機動戦士ガンダム 復讐のレクイエム"),
    ("レクイエム", "機動戦士ガンダム 復讐のレクイエム"),
    ("ソラリ", "機動戦士ガンダム 復讐のレクイエム"),
    ("ガンダムEX", "機動戦士ガンダム 復讐のレクイエム"),
    
    # Mercury
    ("水星の魔女", "機動戦士ガンダム 水星の魔女"),
    ("エアリアル", "機動戦士ガンダム 水星の魔女"),
    ("ルブリス", "機動戦士ガンダム 水星の魔女"),
    ("キャリバーン", "機動戦士ガンダム 水星の魔女"),
    ("シュバルゼッテ", "機動戦士ガンダム 水星の魔女"),
    ("ミカエリス", "機動戦士ガンダム 水星の魔女"),
    ("デミトレーナー", "機動戦士ガンダム 水星の魔女"),
    ("ディランザ", "機動戦士ガンダム 水星の魔女"),
    ("ダリルバルデ", "機動戦士ガンダム 水星の魔女"),
    ("ファラクト", "機動戦士ガンダム 水星の魔女"),
    
    # IBO
    ("鉄血", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("バルバトス", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("グシオン", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("キマリス", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("アスタロト", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("ヴィダール", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("バエル", "機動戦士ガンダム 鉄血のオルフェンズ"),
    ("端白星", "機動戦士ガンダム 鉄血のオルフェンズ ウルズハント"),

    # SEED FREEDOM
    ("SEED FREEDOM", "機動戦士ガンダムSEED FREEDOM"),
    ("ライジングフリーダム", "機動戦士ガンダムSEED FREEDOM"),
    ("イモータルジャスティス", "機動戦士ガンダムSEED FREEDOM"),
    ("マイティーストライクフリーダム", "機動戦士ガンダムSEED FREEDOM"),
    ("ストライクフリーダムガンダム弐式", "機動戦士ガンダムSEED FREEDOM"),
    ("インフィニットジャスティスガンダム弐式", "機動戦士ガンダムSEED FREEDOM"),
    ("SpecII", "機動戦士ガンダムSEED FREEDOM"),
    ("Spec II", "機動戦士ガンダムSEED FREEDOM"),
    ("ブラックナイト", "機動戦士ガンダムSEED FREEDOM"),
    ("ゲルググメナース", "機動戦士ガンダムSEED FREEDOM"),
    ("ギャンシュトローム", "機動戦士ガンダムSEED FREEDOM"),

    # SEED DESTINY
    ("SEED DESTINY", "機動戦士ガンダムSEED DESTINY"),
    ("デスティニー", "機動戦士ガンダムSEED DESTINY"),
    ("インパルス", "機動戦士ガンダムSEED DESTINY"),
    ("ストライクフリーダム", "機動戦士ガンダムSEED DESTINY"),
    ("インフィニットジャスティス", "機動戦士ガンダムSEED DESTINY"),
    ("レジェンドガンダム", "機動戦士ガンダムSEED DESTINY"),
    ("セイバーガンダム", "機動戦士ガンダムSEED DESTINY"),
    ("カオスガンダム", "機動戦士ガンダムSEED DESTINY"),
    ("アビスガンダム", "機動戦士ガンダムSEED DESTINY"),
    ("ガイアガンダム", "機動戦士ガンダムSEED DESTINY"),
    ("ザクウォーリア", "機動戦士ガンダムSEED DESTINY"),
    ("グフイグナイテッド", "機動戦士ガンダムSEED DESTINY"),
    ("ドムトルーパー", "機動戦士ガンダムSEED DESTINY"),
    ("ウィンダム", "機動戦士ガンダムSEED DESTINY"),
    ("ムラサメ", "機動戦士ガンダムSEED DESTINY"),
    ("暁", "機動戦士ガンダムSEED DESTINY"),
    ("アカツキ", "機動戦士ガンダムSEED DESTINY"),

    # SEED
    ("SEED", "機動戦士ガンダムSEED"),
    ("ASTRAY", "機動戦士ガンダムSEED ASTRAY"),
    ("アストレイ", "機動戦士ガンダムSEED ASTRAY"),
    ("エールストライク", "機動戦士ガンダムSEED"),
    ("ストライクガンダム", "機動戦士ガンダムSEED"),
    ("イージスガンダム", "機動戦士ガンダムSEED"),
    ("デュエルガンダム", "機動戦士ガンダムSEED"),
    ("バスターガンダム", "機動戦士ガンダムSEED"),
    ("ブリッツガンダム", "機動戦士ガンダムSEED"),
    ("フリーダムガンダム", "機動戦士ガンダムSEED"),
    ("ジャスティスガンダム", "機動戦士ガンダムSEED"),
    ("プロヴィデンス", "機動戦士ガンダムSEED"),
    ("ジン", "機動戦士ガンダムSEED"),
    ("シグー", "機動戦士ガンダムSEED"),
    ("バクゥ", "機動戦士ガンダムSEED"),
    ("ラゴゥ", "機動戦士ガンダムSEED"),
    
    # Generic Strike rule (Must be after DESTINY/FREEDOM)
    ("ストライク", "機動戦士ガンダムSEED"), 
    
    # First Gundam Ships
    ("サラミス", "機動戦士ガンダム"),
    ("マゼラン", "機動戦士ガンダム"),
    ("ドップ", "機動戦士ガンダム"),
    ("ドダイ", "機動戦士ガンダム"),
    ("マゼラ", "機動戦士ガンダム"),
    ("ムサイ", "機動戦士ガンダム"),
    ("ホワイトベース", "機動戦士ガンダム"),

    # 00
    ("機動戦士ガンダム00", "機動戦士ガンダム00"), 
    ("ダブルオー", "機動戦士ガンダム00"),
    ("クアンタ", "機動戦士ガンダム00"),
    ("エクシア", "機動戦士ガンダム00"),
    ("デュナメス", "機動戦士ガンダム00"),
    ("キュリオス", "機動戦士ガンダム00"),
    ("ヴァーチェ", "機動戦士ガンダム00"),
    ("ナドレ", "機動戦士ガンダム00"),
    ("ケルディム", "機動戦士ガンダム00"),
    ("アリオス", "機動戦士ガンダム00"),
    ("セラヴィー", "機動戦士ガンダム00"),
    ("セラフィム", "機動戦士ガンダム00"),
    ("ハルート", "機動戦士ガンダム00"),
    ("サバーニャ", "機動戦士ガンダム00"),
    ("ラファエル", "機動戦士ガンダム00"),
    ("スサノオ", "機動戦士ガンダム00"),
    ("マスラオ", "機動戦士ガンダム00"),
    ("リボーンズ", "機動戦士ガンダム00"),
    ("ジンクス", "機動戦士ガンダム00"),
    ("ユニオンフラッグ", "機動戦士ガンダム00"),
    ("ティエレン", "機動戦士ガンダム00"),
    ("イナクト", "機動戦士ガンダム00"),

    # Unicorn
    ("ユニコーン", "機動戦士ガンダムUC"),
    ("バンシィ", "機動戦士ガンダムUC"),
    ("クシャトリヤ", "機動戦士ガンダムUC"),
    ("シナンジュ", "機動戦士ガンダムUC"),
    ("リゼル", "機動戦士ガンダムUC"),
    ("デルタプラス", "機動戦士ガンダムUC"),
    ("ジェスタ", "機動戦士ガンダムUC"),
    ("アンクシャ", "機動戦士ガンダムUC"),
    ("ローゼン・ズール", "機動戦士ガンダムUC"),
    ("ギラ・ズール", "機動戦士ガンダムUC"),
    
    # Narrative
    ("ナラティブ", "機動戦士ガンダムNT"),
    ("フェネクス", "機動戦士ガンダムNT"), 
    ("スタイン", "機動戦士ガンダムNT"), 

    # Hathaway
    ("閃光のハサウェイ", "機動戦士ガンダム 閃光のハサウェイ"),
    ("クスィー", "機動戦士ガンダム 閃光のハサウェイ"),
    ("ペーネロペー", "機動戦士ガンダム 閃光のハサウェイ"),
    ("メッサー", "機動戦士ガンダム 閃光のハサウェイ"),

    # Thunderbolt
    ("サンダーボルト", "機動戦士ガンダム サンダーボルト"),
    ("フルアーマー・ガンダム", "機動戦士ガンダム サンダーボルト"), 
    ("サイコ・ザク", "機動戦士ガンダム サンダーボルト"),
    ("アトラスガンダム", "機動戦士ガンダム サンダーボルト"),
]

# Build Specifics (Check these FIRST)
build_keywords = [
    ("ビルド", "ガンダムビルドシリーズ"),
    ("ダイバー", "ガンダムビルドシリーズ"),
    ("ファイターズ", "ガンダムビルドシリーズ"),
    # REMOVED: "トライ", "サラ"
    ("メタバース", "ガンダムビルドシリーズ"),
    ("メイジン", "ガンダムビルドシリーズ"),
    ("戦国アストレイ", "ガンダムビルドシリーズ"),
    ("ウイングガンダムフェニーチェ", "ガンダムビルドシリーズ"),
    ("ベアッガイ", "ガンダムビルドシリーズ"),
    ("モモカプル", "ガンダムビルドシリーズ"),
    ("ダイバーナミ", "ガンダムビルドシリーズ"),
    ("モビルドールサラ", "ガンダムビルドシリーズ"),
    ("パーフェクトストライクフリーダム", "ガンダムビルドシリーズ"),
    ("ブレイカー", "ガンダムビルドシリーズ"),
    ("バトローグ", "ガンダムビルドシリーズ"),
]

# SD Specifics
sd_keywords = ["SD", "BB戦士", "クロスシルエット", "SDW", "三国創傑伝", "EXスタンダード"]

fixed_count = 0

with open(input_file, 'r', encoding='utf-8') as fin, \
     open(output_file, 'w', encoding='utf-8', newline='') as fout:
    
    reader = csv.reader(fin)
    writer = csv.writer(fout)
    
    for row in reader:
        if not row:
            continue
            
        title = row[1]
        series = row[3]
        grade = row[4] if len(row) > 4 else ""
        
        # Skip Header
        if "Title" in title:
            writer.writerow(row)
            continue

        original_series = series
        new_series = series

        # 1. SD Check (Override everything)
        is_sd = False
        for k in sd_keywords:
            if k in title or (len(row) > 4 and k in grade):
                is_sd = True
                break
        
        if is_sd:
            new_series = "SDガンダムシリーズ"
        else:
            # 2. Build Series Check
            is_build = False
            for k, s in build_keywords:
                if k in title:
                    new_series = s
                    is_build = True
                    break
            
            # 3. Main Series Check (if not Build)
            if not is_build:
                # Iterate mapping
                for k, s in series_map:
                    if k in title:
                        new_series = s
                        break
        
        # Apply change if different and not empty
        if new_series != original_series:
            row[3] = new_series
            fixed_count += 1
            # print(f"Fixed: {title} | {original_series} -> {new_series}")
        
        writer.writerow(row)

print(f"Total series normalized: {fixed_count}")

# Replace original
shutil.move(output_file, input_file)
