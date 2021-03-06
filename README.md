【説明】
パーティション区分けされたイメージファイルを作成するソフト。
OSのイメージは最大で4つまで指定することができる。
このソフトに指定するOSのイメージには制約があり、PBR(ブートローダ)は506番地に存在するOSのオフセットと510番地に存在するOSのサイズを利用してブートしなければならないし、LBA方式でOSをロードする必要がある。
最後の大きな制約として、パーティションに指定するOSイメージはPBRの直後にOSのブートローダを置いておく必要がある。

【使い方】
1. imgディレクトリにパーティションにしたいOSのイメージを4つまで置いておく
2. Make_Partitionディレクトリに戻り、makeを打ち込む
3. Make_PartitionディレクトリにできたDISK.imgをディスクに焼く
4. PCのBiosで起動ディスクの優先順位を設定し起動する

【作者メモ】
PBRのリンカスクリプトのVMAは0x0であっても0x7c00であってもパーティションにできた。
起動ディスクはLBA方式に対応しているディスクのみであり(MBRがPBRのロードにLBA方式を用いているため)、当然パーティション側がそのディスクに対応している必要(PBRは506,510番地の情報を用いて、LBA方式でOSをロードする必要があるため)もある。
