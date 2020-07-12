##### mbrへの書き込みに使用するオフセット #####
##### OSNAMEは8byteで、先頭1byteが0でない場合OSが存在する。LEAD_SECは、LBA方式でそのパーティションが起動ディスクの先頭から何セクタ目に存在するかという情報へのオフセット #####
.equ	PART1_OSNAME, 462
.equ	PART1_LEAD_SEC, 470
.equ	PART2_OSNAME, 474
.equ	PART2_LEAD_SEC, 482
.equ	PART3_OSNAME, 486
.equ	PART3_LEAD_SEC, 494
.equ	PART4_OSNAME, 498
.equ	PART4_LEAD_SEC, 506

##### リアルモードで動作するので16bit用の機械語を生成する #####
.code16

##### .text領域にプログラムを配置する #####
.text

##### mbrを「とりあえず」動かすためにセグメントレジスタを初期化している #####
	sti					# biosがstiし忘れていても大丈夫なように。
	ljmpw	$0x07c0, $init_segment_regs	# biosからはljmpw $0x0000, $0x7c00でジャンプしているはずなので、機械語(.textや.data)のVMAを0にするためにcsを7c0に初期化する。
init_segment_regs:
	movw	%cs, %ax			# csの値(0x07c0)を他のレジスタにも代入したい。(movw $0x07c0, セグメントレジスタよりも機械語のサイズが小さい)
	movw	%ax, %ds			# ds=0x07c0
	xorw	%ax, %ax			# ax=0
	movw	%ax, %ss			# ss=0
	movw	$0x7a00, %sp			# sp=0x7a00(0x7c00でいいと思われるかもだが、0x7a00にmbrをコピーするため、0x7a00-0x7bffを破壊するわけには行かない)

##### HDD系のデバイスから起動しているのかを確認し、ドライブ番号を保存しておく(mbrの最後にドライブ番号が必要なため) #####
check_drv_num:
	movb	%dl, (drv)			# dlには起動時にドライブ番号が入っている
	cmpb	$0x80, %dl			# ドライブ番号が0の場合はAドライブ(つまりFD)、0x80以上の場合は固定ディスク(つまりUSBやSDカードなどのHDD系ドライブ)であるらしい。。。
	jb	unsupported			# もし、起動ドライブの番号が0x80より小さいなら、このmbrはそのデバイスをサポートしていません。

##### pbrを0x7c00にロードするために、mbrは0x7a00に自分自身をコピーする #####
cpy_mbr:
	xorw	%si, %si			# ds:si=0x07c0:0x0000=0x7c00
	movw	$0x07a0, %ax
	movw	%ax, %es			# es:di=0x07a0:0x0000=0x7a00
	xorw	%di, %di
	movw	$512/2, %cx			# loop 256 times
cpy_mbr_loop:
	lodsw
	stosw
	decw	%cx
	jnz	cpy_mbr_loop
	ljmpw	$0x07a0, $set_segm_regs

##### mbrは0x7a00にロードされたので、dsも0x07a0を指すようにしておく #####
set_segm_regs:
	movw	%cs, %ax
	movw	%ax, %ds

##### pbrの情報を表示する(OS名の先頭がなる文字だった場合、OSが存在しないこととする) #####
##### part_flagの下4bitはそれぞれパーティションが存在するかどうかのフラグになっている(bit0:PART1, bit1:PART2, bit2:PART3, bit3:PART4) #####
print_pbr_info:
	movw	$pbr_info_msg, %si
	call	print_str

print_part1_info:
	movb	(PART1_OSNAME), %al
	andb	%al, %al
	jz	print_part2_info
	movw	$msg1, %si
	call	print_str
	movw	$PART1_OSNAME, %si
	call	print_str
	orb	$1, (part_flag)

print_part2_info:
	movb	(PART2_OSNAME), %al
	andb	%al, %al
	jz	print_part3_info
	movw	$msg2, %si
	call	print_str
	movw	$PART2_OSNAME, %si
	call	print_str
	orb	$2, (part_flag)

print_part3_info:
	movb	(PART3_OSNAME), %al
	andb	%al, %al
	jz	print_part4_info
	movw	$msg3, %si
	call	print_str
	movw	$PART3_OSNAME, %si
	call	print_str
	orb	$4, (part_flag)

print_part4_info:
	movb	(PART4_OSNAME), %al
	andb	%al, %al
	jz	part_check
	movw	$msg4, %si
	call	print_str
	movw	$PART4_OSNAME, %si
	call	print_str
	orb	$8, (part_flag)

##### もし、どのパーティションも存在しなかったら"load error"と表示する(makeの時点でエラーが出ているはずではあるのだが) #####
part_check:
	cmpb	$0, (part_flag)
	je	error

##### キーボード入力(1~4)により、起動するOSを選択する #####
##### ただし、存在する番号以外を入力したときにはエラーになるし、1~4以外の文字は無視される #####
select_part:
	movw	$select_msg, %si
	call	print_str
wait_kbd:
	movb	$0x00, %ah			# ah=0x00でint 0x16とするとキーボード入力が使える。結果はalにアスキーコードで格納され、ahには押したときのスキャンコードが格納される。
	int	$0x16
	cmpb	$0x31, %al
	jb	wait_kbd
	cmpb	$0x34, %al
	ja	wait_kbd
	andb	$0x0f, %al			# 上記の処理により、ここではalの値は0x31~0x34だけである。ここでalの下位4bitをandで掠め取ると、アスキーコードから数に変換できる。
	movb	%al, %bl			# 押した番号をblに一旦保存しておく。
	decb	%al				# shlb $al, $1として、part_flagの内容とのandを取るとそのパーティションが存在するかを判定できるようにするために-1しておく。
	movb	%al, %cl			# shlb命令の左のオペランドにはレジスタだとclしか指定できない。
	movb	$0x01, %al
	shlb	%cl, %al			# al = 1 << (パーティション番号 - 1) と同義。
	andb	(part_flag), %al		# 押した番号に対応するパーティションが存在したらalは真、しない場合は偽を指す。
	jz	error				# もし、パーティションが見つからなかったらエラー。

set_part_info:
	movb	%bl, %al			# alの初期化。blにはキーボードで押したアスキーコードを数字に変換したものが入っている。
	xorb	%ah, %ah			# ahを0に初期化する。
	shlw	$2, %ax				# ax = パーティション番号 * 4
	movw	%ax, %bx			# bx = パーティション番号 * 4
	shlw	$1, %ax				# ax = パーティション番号 * 8
	addw	%ax, %bx			# bx = パーティション番号 * 12
	addw	$458, %bx			# パーティションテーブルは、mbrのオフセット462, 474, 486, 498からそれぞれ配置される。「bx = 450 + 12 * パーティション番号 + 8」で、各PARTのオフセットが得られる。
	movl	(%bx), %ebx			# パーティションのサイズは4byteのデータなので、4byteのデータバスを利用する。
	movl	%ebx, (lba0)			# lba0の部分を書き換える。

##### USBのデータをメモリにロードするための準備エントリ #####
check_usbboot:
	movb	$0x41, %ah			# ah = 0x41 →  拡張INT13命令に対応しているかを調べる
	movw	$0x55aa, %bx
	int	$0x13
	jc	unsupported

	cmpw	$0xaa55, %bx			# BX == 0xaa55 ： 拡張IN13Hはインストールされている
	jne	unsupported

	test	$0x01, %cl			# CL.bit0 == 1 ： 拡張ディスクアクセスをサポートしている
	jz	unsupported

##### USBの中にあるセカンドローダを順番に読んでいって、メモリ上に展開する処理(LBA方式) #####
read_disk:
	xorb	%cl, %cl			# clはそのセクタを何回読み込もうとしたのかを記憶するレジスタ
retry:
	incb	%cl				# 試行回数 + 1

	movb	(drv), %dl			# dl = 読み込みを行うドライブ番号
	movb	$0x42, %ah			# 拡張ディスクリード
	movw	$DAPS, %si
	int	$0x13
	jnc	next				# USBからメモリへのロードが一回分、無事に完了した

	movb	(drv), %dl
	movb	$0x00, %ah
	int	$0x13				# ドライブのリセット

	cmpb	$0x5, %cl			# 試行回数が5回以上になったときエラー
	jae	error
	jmp	retry				# 5回以下のミスはたまたまの可能性があるのでもう一度試してみる。(qemuではイメージファイルより、幾分か多くのセクタを読み込むとエラーになるらしい。)

##### pbrを呼び出すが、その前にBIOSから呼び出された状況とできるだけ近づけておく #####
##### cs=0x0000, ds=0x0000, dl=起動ディスク番号 は保証されている(pbrのために最低限設定しておかねばならないレジスタ) #####
next:
	movb	(drv), %dl			# 起動ディスクの番号をpbrのためにdlに入れ直しておく。(できるだけ、BIOSからの呼び出しに近づけたい。)
	xorw	%ax, %ax
	movw	%ax, %ds
	ljmpw	$0x0000, $0x7c00		# biosから呼び出されたのとだいたい同じ状況でpbrを呼び出す。(esとかはBIOS直後と比べて値が変わっているけど、pbrでesを使用する場合はどうせ初期化するはずなのでOK)

##### 文字列を表示する #####
print_str:
	lodsb
	cmpb	$0, %al
	je	print_str_end
	movb	$0x0e, %ah
	movw	$0, %bx
	int	$0x10
	jmp	print_str
print_str_end:
	ret

##### BIOSが対応していなかったり、エラーが出たときにはこの部分を参照する #####
unsupported:
	movw	$not_supported_msg, %si
	call	print_str
	jmp	error_loop
error:
	movw	$load_error_msg, %si
	call	print_str
error_loop:
	hlt
	jmp	error_loop

##### データを保管しておくセクション #####
.data

##### エラーメッセージ一覧 #####
not_supported_msg:
	.string	"mbr.s: unsupported."   
load_error_msg:
	.string	"mbr.s: load error."
pbr_info_msg:
	.string "# pbr INFO #\n"
msg1:
	.string "\r\n1>"
msg2:
	.string "\r\n2>"
msg3:
	.string "\r\n3>"
msg4:
	.string "\r\n4>"
select_msg:
	.string "\r\n\nPut 1-4 from table above.\r\n"

##### ドライブ番号を記憶しておく #####
drv:
	.byte	0x80

##### ロード可能なパーティションかどうか #####
##### bit0:part1, bit1:part2, bit2:part3, bit3:part4 #####
part_flag:
	.byte	0x00

##### Disk Address Packet #####
DAPS:
	.word	0x0010				# Size of Structure (16 bytes, always this for DAPS)
	.word	0x0001				# Number of Sectors to Read (1x512)
addr:
	.word	0x0000				# Target Location for Reading To (0x8000 = 0x0800:0x0000)  
segm:
	.word	0x07c0				# Page Table (0, Disabled)
lba0:
	.int	0x00000000			# Read from 2nd block (code I want to load)
	.int	0x00000000			# Large LBAs, dunno what this does

##### 「.byte 0x55, 0xaa」についてはipl.lsで組み込んでいるので、ipl.sでは記述する必要はない #####
